import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import window from '@ohos.window';
import display from '@ohos.display';
import { NavigationHelper } from '../../../core/utils/NavigationHelper';
import AccountManager, { Account } from '../../../core/auth/AccountManager';
import Avatar from '../../../components/Avatar';
import UserProfileRepository from '../../../core/repository/UserProfileRepository';
import { Dict } from '../../../core/types/Dict';
import { getStr, buildPortraitUrl, blendWithBg, textAccent, pageBg, cardBg, cardRadius, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor, darkenColor, withAlpha } from '../../../core/utils/DataHelper';
import ThemeProvider from '../../../core/theme/ThemeProvider';
import { DarkMode } from '../../../core/theme/ThemeConfig';
import DeviceFingerprint from '../../../core/device/DeviceFingerprint';
import { ClientVersion } from '../../../core/network/HttpConstants';

@Component
export default struct UserTabPage {
  @Prop @Watch('onActiveChanged') active: boolean = true;
  @StorageLink('primaryColor') @Watch('onColorChanged') primaryColor: string = '#4477E0';
  reduceEffects: boolean = false;
  @State bgColor: string = pageBg(AppStorage.Get<boolean>('isDarkTheme') ?? false);
  @State account: Dict | null = null;
  @State isLoggedIn: boolean = false;
  @State allAccounts: Account[] = [];
  @State showAccountPanel: boolean = false;
  @State postCount: string = '';
  @State fansCount: string = '';
  @State followCount: string = '';
  @StorageLink('darkMode') darkModeSetting: number = DarkMode.FOLLOW_SYSTEM;
  @StorageLink('isSystemDark') isSystemDark: boolean = false;
  @StorageLink('isDarkTheme') @Watch('onColorChanged') isDark: boolean = false;
  @StorageLink('headerAlpha') headerAlpha: number = 25;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @StorageLink('cardStyle') cardStyle: number = 0;
  @State topInset: number = 24;

  private darkModeOptions: string[] = ['跟随系统', '浅色模式', '深色模式'];
  private accountManager: AccountManager = AccountManager.getInstance();
  private profileRepo: UserProfileRepository = UserProfileRepository.getInstance();

  onColorChanged(): void {
    this.bgColor = pageBg(this.isDark);
  }

  onActiveChanged(): void {
    this.reduceEffects = AppStorage.get<boolean>('reduceEffects') === true;
    if (!this.active) {
      this.showAccountPanel = false;
    }
  }

  aboutToAppear(): void {
    console.info('TiebaLite: UserTab aboutToAppear');
    this.initTopInset();
    this.refreshAccountState();
    this.accountManager.onAccountChange((acc: Account | null): void => {
      console.info('TiebaLite: UserTab onAccountChange loggedIn=' + (acc !== null));
      this.account = acc as Object as Dict | null;
      this.isLoggedIn = acc !== null;
      this.allAccounts = this.accountManager.getAllAccounts();
      void this.loadProfileStats();
    });
  }

  private initTopInset(): void {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      window.getLastWindow(ctx).then((win: window.Window) => {
        const avoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        if (avoidArea.topRect.height > 0) {
          const density = display.getDefaultDisplaySync().densityPixels;
          this.topInset = Math.max(20, Math.round(avoidArea.topRect.height / density));
        }
      }).catch(() => { });
    } catch (e) {
      console.warn('TiebaLite: UserTab initTopInset failed ' + JSON.stringify(e));
    }
  }

  private refreshAccountState(): void {
    this.isLoggedIn = this.accountManager.isLoggedIn();
    this.allAccounts = this.accountManager.getAllAccounts();
    const acc = this.accountManager.getCurrentAccountSync();
    console.info('TiebaLite: UserTab refreshAccountState loggedIn=' + this.isLoggedIn + ' acc=' + (acc !== null) + ' uid=' + (acc ? acc.uid : -1));
    this.account = acc as Object as Dict | null;
    if (acc) {
      void this.loadProfileStats();
    }
  }

  private isLoadingStats: boolean = false;

  private async loadProfileStats(): Promise<void> {
    if (this.isLoadingStats) return;
    this.isLoadingStats = true;
    const acc = this.accountManager.getCurrentAccountSync();
    if (!acc) { this.isLoadingStats = false; return; }
    const uid = acc.uid;
    console.info('TiebaLite: UserTab loadProfileStats uid=' + uid);

    // Try protobuf API first
    try {
      const prof = await this.profileRepo.loadProfileProtobufDirect(uid);
      console.info('TiebaLite: UserTab proto direct thread=' + prof.threadNum + ' post=' + prof.postNum + ' fans=' + prof.fanNum + ' follow=' + prof.followNum);
      if (prof.threadNum > 0 || prof.postNum > 0 || prof.fanNum > 0 || prof.followNum > 0) {
        this.postCount = String(prof.threadNum > 0 ? prof.threadNum : prof.postNum);
        this.fansCount = String(prof.fanNum);
        this.followCount = String(prof.followNum);
        console.info('TiebaLite: UserTab proto success posts=' + this.postCount + ' fans=' + this.fansCount + ' follow=' + this.followCount);
        this.isLoadingStats = false;
        return;
      }
    } catch (e) {
      console.info('TiebaLite: UserTab proto failed: ' + String(e));
    }

    // Fallback: try all JSON APIs
    let data: Dict | null = null;
    try { data = await this.profileRepo.loadProfile(uid); console.info('TiebaLite: UserTab loadProfile ok'); } catch (e) { console.info('TiebaLite: UserTab loadProfile fail: ' + String(e)); }
    if (!data) { try { data = await this.profileRepo.loadStatsViaMiniApi(uid); console.info('TiebaLite: UserTab miniApi ok'); } catch (e2) { console.info('TiebaLite: UserTab miniApi fail: ' + String(e2)); } }
    if (!data) { try { data = await this.profileRepo.loadStatsViaUserInfo(uid); console.info('TiebaLite: UserTab userInfo ok'); } catch (e3) { console.info('TiebaLite: UserTab userInfo fail: ' + String(e3)); } }

    if (data) {
      const raw = (data?.data || data) as Dict;
      const rawUser = raw.user as Dict || {};
      console.info('TiebaLite: UserTab respKeys=' + Object.keys(raw).join(',') + ' userKeys=' + (rawUser ? Object.keys(rawUser).join(',') : 'null'));
      const pc = getStr(rawUser, 'thread', 'threadNum', 'thread_num', 'thread_count')
        || getStr(raw, 'thread', 'threadNum', 'thread_num', 'thread_count') || '';
      const fc = getStr(rawUser, 'fans', 'fansNum', 'fans_num', 'follower_count', 'followers')
        || getStr(raw, 'fans', 'fansNum', 'fans_num', 'follower_count', 'followers') || '';
      const flc = getStr(rawUser, 'follow', 'followNum', 'follow_num', 'following_count', 'concernNum', 'concern_num', 'following')
        || getStr(raw, 'follow', 'followNum', 'follow_num', 'following_count', 'concernNum', 'concern_num', 'following') || '';
      if (pc) this.postCount = pc;
      if (fc) this.fansCount = fc;
      if (flc) this.followCount = flc;
      console.info('TiebaLite: UserTab parsed posts=' + this.postCount + ' fans=' + this.fansCount + ' follow=' + this.followCount);
    }

    this.isLoadingStats = false;
  }

  private openServiceCenter(): void {
    const fp = DeviceFingerprint.getInstance();
    const cuid = fp.getCuid();
    const cuidGalaxy2 = fp.getCuidGalaxy2();
    const cuidGid = fp.getCuidGid();
    const timestamp = String(Date.now());
    const url = 'https://tieba.baidu.com/mo/q/hybrid-main-service/uegServiceCenter'
      + '?cuid=' + cuid
      + '&cuid_galaxy2=' + cuidGalaxy2
      + '&cuid_gid=' + cuidGid
      + '&timestamp=' + timestamp
      + '&_client_version=' + ClientVersion.TIEBA_V12
      + '&nohead=1';
    NavigationHelper.navigate('pages/webview/WebViewPage', { url: url, title: '客服信息' });
  }

  private toggleAccountPanel(): void {
    this.allAccounts = this.accountManager.getAllAccounts();
    this.showAccountPanel = !this.showAccountPanel;
  }

  private async switchToAccount(account: Account): Promise<void> {
    await this.accountManager.setCurrentAccount(account);
    AppStorage.Set<boolean>('homeInitialLoadDone', false);
    AppStorage.Set<boolean>('exploreInitialLoadDone', false);
    AppStorage.Set<boolean>('notifInitialLoadDone', false);
    AppStorage.Set<boolean>('storeInitialLoadDone', false);
    this.allAccounts = this.accountManager.getAllAccounts();
    this.showAccountPanel = false;
  }

  private async doLogout(): Promise<void> {
    AlertDialog.show({
      title: '退出登录',
      message: '确定要退出当前账号吗？',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '确定',
          action: async () => {
            await this.accountManager.logout();
            this.isLoggedIn = false;
            this.account = null;
            this.showAccountPanel = false;
        }
      },
      cancel: () => {}
    });
  }

  private openUserProfile(type: string): void {
    const acc = this.accountManager.getCurrentAccountSync();
    if (!acc) return;
    if (type === 'fans') {
      NavigationHelper.navigate('pages/user/FollowsPage', { uid: String(acc.uid), initialTab: 0 });
    } else if (type === 'follow') {
      NavigationHelper.navigate('pages/user/FollowsPage', { uid: String(acc.uid), initialTab: 1 });
    } else {
      NavigationHelper.navigate('pages/user/UserProfilePage', { uid: String(acc.uid) });
    }
  }

  build() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor(this.bgColor)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      Column() {
        Scroll() {
        Column() {
          Blank().height(16)
          if (this.isLoggedIn && this.account) {
            Column() {
              Row() {
                Avatar({ portrait: buildPortraitUrl(String(this.account.portrait || '')), avatarSize: 56, defaultName: String(this.account.nickname || this.account.name || '') })
                Column() {
                  Text(String(this.account.nickname || this.account.name))
                    .fontFamily(this.appFontFamily).fontSize(18).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark))
                  Text('ID: ' + String(this.account.name))
                    .fontFamily(this.appFontFamily).fontSize(13).fontColor(textTertiary(this.isDark))
                    .margin({ top: 4 })
                }
                .margin({ left: 12 })
                .alignItems(HorizontalAlign.Start)
                Blank()
                Text('切换').fontFamily(this.appFontFamily).fontSize(14).fontColor(textAccent(this.primaryColor, this.isDark))
                  .onClick(() => { this.toggleAccountPanel(); })
              }
              .width('100%').padding(16)
            }
            .width('100%')
            .margin({ top: 16, left: 12, right: 12 })
            .onClick(() => { this.openUserProfile('profile'); })


          } else {
            Column() {
              Circle().width(56).height(56).fill('#E0E0E0')
              Text('点击登录').fontFamily(this.appFontFamily).fontSize(16).fontColor('#4477E0').margin({ top: 8 })
              Text('登录体验全部功能').fontFamily(this.appFontFamily).fontSize(13).fontColor(textTertiary(this.isDark)).margin({ top: 4 })
            }
            .width('100%').padding(24)
            .backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(12))
            .margin({ top: 16, left: 12, right: 12 })
            .onClick(() => { NavigationHelper.navigate('pages/login/LoginPage'); })
          }

          if (this.isLoggedIn) {
            Row() {
              Column() {
                Text(this.postCount && this.postCount !== '0' ? this.postCount : '-').fontFamily(this.appFontFamily).fontSize(18).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark))
                Text('帖子').fontFamily(this.appFontFamily).fontSize(13).fontColor(textTertiary(this.isDark)).margin({ top: 2 })
              }
              .layoutWeight(1).alignItems(HorizontalAlign.Center)
              .onClick(() => { this.openUserProfile('thread'); })
              Column() {
                Text(this.fansCount && this.fansCount !== '0' ? this.fansCount : '-').fontFamily(this.appFontFamily).fontSize(18).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark))
                Text('粉丝').fontFamily(this.appFontFamily).fontSize(13).fontColor(textTertiary(this.isDark)).margin({ top: 2 })
              }
              .layoutWeight(1).alignItems(HorizontalAlign.Center)
              .onClick(() => { this.openUserProfile('fans'); })
              Column() {
                Text(this.followCount && this.followCount !== '0' ? this.followCount : '-').fontFamily(this.appFontFamily).fontSize(18).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark))
                Text('关注').fontFamily(this.appFontFamily).fontSize(13).fontColor(textTertiary(this.isDark)).margin({ top: 2 })
              }
              .layoutWeight(1).alignItems(HorizontalAlign.Center)
              .onClick(() => { this.openUserProfile('follow'); })
            }
            .width('100%').padding({ top: 16, bottom: 16, left: 16, right: 16 })
            .backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(12))
            .margin({ top: 12, left: 12, right: 12 })
          }

          Column() {
            this.menuItem($r('app.media.ic_brush'), '主题', () => NavigationHelper.navigate('pages/settings/AppThemePage'))
            this.menuItem($r('app.media.ic_download'), '收藏', () => NavigationHelper.navigate('pages/threadstore/ThreadStorePage'))
            this.menuItem($r('app.media.ic_history'), '历史', () => NavigationHelper.navigate('pages/history/HistoryPage'))
            this.menuItem($r('app.media.ic_info'), '客服', () => this.openServiceCenter())
            this.menuItem($r('app.media.ic_settings'), '设置', () => NavigationHelper.navigate('pages/settings/SettingsPage'))
            this.menuItem($r('app.media.ic_info'), '关于', () => NavigationHelper.navigate('pages/settings/AboutPage'))
          }
          .width('100%').backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(12))
          .margin({ top: 12, left: 12, right: 12 }).padding({ top: 8, bottom: 8 })

          Column() {
            Row() {
              Text('深色模式').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Select(this.darkModeOptions.map((s: string): SelectOption => ({ value: s })))
                .selected(this.darkModeSetting > 2 ? 2 : this.darkModeSetting)
                .value(this.darkModeOptions[this.darkModeSetting > 2 ? 2 : this.darkModeSetting])
                .fontColor('#4477E0')
                .onSelect(async (idx: number) => {
                  await ThemeProvider.getInstance().setDarkMode(idx as DarkMode);
                  if (idx === DarkMode.FOLLOW_SYSTEM) {
                    ThemeProvider.getInstance().setSystemDark(this.isSystemDark);
                  }
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })
          }
          .width('100%').backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(12))
          .margin({ top: 12, left: 12, right: 12 }).padding({ top: 0, bottom: 8 })

          if (this.isLoggedIn) {
            Button('退出登录').width('100%').height(48)
              .fontColor('#FF4444').backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(12))
              .margin({ top: 24, left: 12, right: 12 })
              .onClick(() => { this.doLogout(); })
          }
        }
        .width('100%').padding({ bottom: 66 })
      }
        .scrollBar(BarState.Off)
        .width('100%').height('100%').edgeEffect(EdgeEffect.Spring).expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

        Column()
          .width('100%')
          .height(48)
          .backgroundColor(withAlpha(this.bgColor, 1 - this.headerAlpha / 100))
          .backdropBlur(60)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
          .position({ x: 0, y: 0 })
          .zIndex(5)
          .hitTestBehavior(HitTestMode.None)

        if (this.showAccountPanel) {
          Column().width('100%').height('100%').position({ x: 0, y: 0 }).onClick(() => { this.showAccountPanel = false; })
          Column() {
        Text('切换账号').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).padding({ left: 16, top: 12, bottom: 8 })

        Column() {
          ForEach(this.allAccounts, (account: Account, idx: number) => {
            Row() {
              Avatar({ portrait: buildPortraitUrl(String(account.portrait || '')), avatarSize: 40, defaultName: account.nickname || account.name })
              Column() {
                Text(account.nickname || account.name).fontFamily(this.appFontFamily).fontSize(15).fontColor(textPrimary(this.isDark)).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text('ID: ' + account.name).fontFamily(this.appFontFamily).fontSize(12).fontColor(textTertiary(this.isDark)).margin({ top: 1 })
              }
              .margin({ left: 10 }).layoutWeight(1).alignItems(HorizontalAlign.Start)
              if (this.account && Number(this.account.uid) === account.uid) {
                Image($r('app.media.ic_check')).width(20).height(20).fillColor(this.primaryColor)
              }
            }
            .width('100%').height(56).padding({ left: 16, right: 16 })
            .onClick(() => { this.switchToAccount(account); })
            if (idx < this.allAccounts.length - 1) {
              Divider().height(0.5).color(dividerColor(this.isDark)).margin({ left: 66 })
            }
          })
        }
        .width('100%').backgroundColor(blendWithBg(this.primaryColor, 0.08, this.isDark))

        Row() {
          Image($r('app.media.ic_add')).width(18).height(18).fillColor(this.primaryColor)
          Text('添加账号').fontFamily(this.appFontFamily).fontSize(15).fontColor(textAccent(this.primaryColor, this.isDark)).margin({ left: 6 })
        }
        .width('100%').height(48).justifyContent(FlexAlign.Center)
        .backgroundColor(blendWithBg(this.primaryColor, 0.08, this.isDark)).borderRadius(0)
        .margin({ top: 0 })
        .onClick(() => {
          this.showAccountPanel = false;
          NavigationHelper.navigate('pages/login/LoginPage');
        })

        Row() {
          Text('账号管理').fontFamily(this.appFontFamily).fontSize(14).fontColor(textSecondary(this.isDark))
          Blank()
          Image($r('app.media.ic_arrow_back')).width(16).height(16).fillColor(textTertiary(this.isDark)).rotate({ angle: 180 })
        }
        .width('100%').height(44).padding({ left: 16, right: 16 })
        .onClick(() => {
          this.showAccountPanel = false;
          NavigationHelper.navigate('pages/settings/AccountManagePage');
        })
      }
      .width('100%')
      .backgroundColor(blendWithBg(this.primaryColor, 0.10, this.isDark))
      .borderRadius(12)
      .padding({ left: 12, right: 12 })
      .position({ top: 156 })
    }
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start).backgroundColor(this.bgColor)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    }
    .width('100%').height('100%')
    .backgroundColor(this.bgColor)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    
  }

  @Builder
  private menuItem(iconRes: Resource, label: string, onClick: () => void) {
    Row() {
      Image(iconRes).width(22).height(22).fillColor(darkenColor(this.primaryColor, 0.25))
      Text(label).fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark)).margin({ left: 16 })
      Blank()
      Image($r('app.media.ic_arrow_back')).width(16).height(16).fillColor(textTertiary(this.isDark)).rotate({ angle: 180 })
    }
    .width('100%').height(48).padding({ left: 16, right: 16 })
    .onClick(() => onClick())
  }
}

