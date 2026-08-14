import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import window from '@ohos.window';
import { NavigationHelper } from '../../../core/utils/NavigationHelper';
import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard';
import display from '@ohos.display';
import { Dict } from '../../../core/types/Dict';
import HomeRepository from '../../../core/repository/HomeRepository';
import AccountManager, { Account } from '../../../core/auth/AccountManager';
import PbPageRepository from '../../../core/repository/PbPageRepository';
import ForumRepository from '../../../core/repository/ForumRepository';
import BlockRepository from '../../../core/repository/BlockRepository';
import ThreadCard from '../../../components/ThreadCard';
import LoadingState from '../../../components/LoadingState';
import ErrorState from '../../../components/ErrorState';
import Avatar from '../../../components/Avatar';
import PullToRefresh from '../../../components/PullToRefresh';
import { TiebaApi } from '../../../core/api/TiebaApi';
import ITiebaApi from '../../../core/api/ITiebaApi';
import PreferencesManager from '../../../core/storage/PreferencesManager';
import { buildPortraitUrl, getStr, getNum, getStrObj, blendWithWhite, darkenColor, blendWithBg, textAccent, pageBg, cardBg, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor, withAlpha } from '../../../core/utils/DataHelper';

@Component
export default struct HomePage {
  @StorageLink('primaryColor') @Watch('onColorChanged') primaryColor: string = '#4477E0';
  reduceEffects: boolean = false;
  @StorageLink('fontScale') fontScale: number = 1.0;
  @StorageLink('cardStyle') cardStyle: number = 0;
  @StorageLink('headerAlpha') headerAlpha: number = 25;
  @StorageLink('headerTint') headerTint: number = 8;
  @StorageLink('isDarkTheme') @Watch('onColorChanged') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @StorageLink('searchBoxRound') searchBoxRound: number = 100;
  @State bgColor: string = pageBg(AppStorage.Get<boolean>('isDarkTheme') ?? false);
  @State feedData: Dict[] = [];
  @State followedForums: Dict[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  @State page: number = 1;
  @State hasMore: boolean = true;
  @State signing: boolean = false;
  @State isLoggedIn: boolean = false;
  @State accountName: string = '';
  @State accountPortrait: string = '';
  @State listMode: boolean = AppStorage.Get<boolean>('homeListMode') ?? true;
  @State signedForumIds: Set<number> = new Set();
  @StorageLink('signedForumIdsArr') signedIdsArr: Object[] = [];
  @StorageLink('recentForumsJson') recentForumsJson: string = '';
  @StorageLink('showRecentForums') showRecentForums: boolean = true;
  @State pendingDeleteForumId: string = '';
  @State showAccountMenu: boolean = false;
  @StorageLink('signBadge') signBadge: boolean = false;
  @State allAccounts: Account[] = [];
  @State @Watch('onRefreshStateChange') isRefreshing: boolean = false;
  @State pullDistance: number = 0;
  @State pullRefreshing: boolean = false;
  @StorageLink('pinnedForumIds') pinnedForumIds: string = '[]';
  @State showForumMenu: boolean = false;
  @State contextMenuForum: Dict | null = null;
  @State contextMenuX: number = 0;
  @State contextMenuY: number = 0;
  @State screenWidth: number = 360;
  @State screenHeight: number = 780;
  @State topInset: number = 24;
  @Prop @Watch('onActiveChanged') active: boolean = true;

  private api: ITiebaApi = TiebaApi.getInstance();
  private recentScroller: Scroller = new Scroller();

  onActiveChanged(): void {
    this.reduceEffects = AppStorage.get<boolean>('reduceEffects') === true;
  }

  onColorChanged(): void {
    this.bgColor = pageBg(this.isDark);
  }

  aboutToAppear(): void {
    const t0 = new Date().getTime();
    console.info('TiebaLite: [H1] HomePage aboutToAppear start t=' + t0);
    this.initTopInset();
    const acct = AccountManager.getInstance().getCurrentAccountSync();
    this.isLoggedIn = acct !== null && acct.bduss.length > 0;
    console.info('TiebaLite: [H2] isLoggedIn=' + this.isLoggedIn + ' t=' + (new Date().getTime() - t0) + 'ms');
    if (this.isLoggedIn) {
      this.accountName = acct!.name || acct!.nickname || '';
      this.accountPortrait = acct!.portrait || '';
    }
    const savedShow = AppStorage.Get<boolean>('showRecentForums');
    if (savedShow !== undefined) AppStorage.SetOrCreate<boolean>('showRecentForums', savedShow);
    if (!this.recentForumsJson) {
      PreferencesManager.getInstance().getString('recent_forums_json').then((saved: string) => {
        if (saved) {
          this.recentForumsJson = saved;
          AppStorage.Set<string>('recentForumsJson', saved);
        }
      }).catch((_e: Error) => {});
    }
    try { this.loadData(); } catch (e) {
      console.error('TiebaLite: [HERR] HomePage aboutToAppear error: ' + JSON.stringify(e));
    }
    AccountManager.getInstance().onAccountChange((_acc: Account | null): void => {
      const acct = AccountManager.getInstance().getCurrentAccountSync();
      this.isLoggedIn = acct !== null && acct.bduss.length > 0;
      if (this.isLoggedIn) {
        this.accountName = acct!.name || acct!.nickname || '';
        this.accountPortrait = acct!.portrait || '';
      }
      void this.loadData();
    });
    try {
      const displayInfo = display.getDefaultDisplaySync();
      this.screenWidth = displayInfo.width / displayInfo.densityPixels;
      this.screenHeight = displayInfo.height / displayInfo.densityPixels;
    } catch (e) {
      console.error('TiebaLite: [HERR] get display info failed: ' + e);
    }
    console.info('TiebaLite: [H3] HomePage aboutToAppear end t=' + (new Date().getTime() - t0) + 'ms');
  }

  onPageShow(): void {
    const v = AppStorage.get<number>('pageShowTick') || 0;
    AppStorage.SetOrCreate('pageShowTick', v + 1);
  }

  onPageHide(): void {
    const v = AppStorage.get<number>('pageHideTick') || 0;
    AppStorage.SetOrCreate('pageHideTick', v + 1);
  }

  private onRefreshStateChange(): void {
    if (this.isRefreshing) {
      this.pullRefreshing = true;
      void this.onPullRefresh();
    } else {
      this.pullRefreshing = false;
      this.pullDistance = 0;
    }
  }

  private triggerRefresh(): void {
    this.pullRefreshing = true;
    const done = (): void => { this.pullRefreshing = false; };
    void this.onPullRefresh().then(done, done);
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
      console.warn('TiebaLite: HomePage initTopInset failed ' + JSON.stringify(e));
    }
  }

  async onPullRefresh(): Promise<void> {
    this.page = 1;
    this.hasMore = true;
    try {
      if (this.isLoggedIn) {
        const results = await Promise.all([
          HomeRepository.getInstance().loadHomeFeed(1),
          this.loadForumData()
        ]);
        const feed: Dict = results[0] as Dict;
        this.feedData = this.extractThreads(feed);
        const forumData: Dict | null = results[1] as Dict | null;
        if (forumData) {
          const forums: Dict[] = this.extractForums(forumData);
          if (forums.length > 0) {
            this.followedForums = forums;
            const signedSet = new Set<number>();
            for (const f of forums) {
              const isSign = getNum(f, 'is_sign', 'isSign', 'sign', 'signed');
              if (isSign > 0) {
                signedSet.add(Number((f as Dict).id || (f as Dict).forum_id || (f as Dict).forumId || 0));
              }
            }
            if (signedSet.size > 0) this.signedForumIds = signedSet;
            else this.signedForumIds = new Set();
          } else {
            this.signedForumIds = new Set();
          }
        } else {
          this.signedForumIds = new Set();
        }
      }
    } catch (e) {
      console.error('TiebaLite: onPullRefresh error=' + String(e));
    } finally {
      this.isRefreshing = false;
    }
  }

  async loadData(): Promise<void> {
    const t0 = new Date().getTime();
    console.info('TiebaLite: [H10] loadData start t=' + t0);
    this.loading = true;
    this.error = '';
    try {
      if (this.isLoggedIn) {
        const results = await Promise.all([
          HomeRepository.getInstance().loadHomeFeed(1),
          this.loadForumData()
        ]);
        const feed: Dict = results[0] as Dict;
        this.feedData = this.extractThreads(feed);
        console.info('TiebaLite: feed threads=' + this.feedData.length);
        const forumData: Dict | null = results[1] as Dict | null;
        if (forumData) {
          const forums: Dict[] = this.extractForums(forumData);
          if (forums.length > 0) {
            this.followedForums = forums;
            const signedSet = new Set<number>();
            for (const f of forums) {
              const isSign = getNum(f, 'is_sign', 'isSign', 'sign', 'signed');
              if (isSign > 0) {
                signedSet.add(Number((f as Dict).id || (f as Dict).forum_id || (f as Dict).forumId || 0));
              }
            }
            if (signedSet.size > 0) this.signedForumIds = signedSet;
          }
        }
      } else {
        this.feedData = [];
      }
    } catch (e) {
      console.error('TiebaLite: [HERR] HomePage loadData error: ' + String(e));
      this.error = '加载失败';
    } finally {
      this.loading = false;
      console.info('TiebaLite: [H11] loadData end t=' + (new Date().getTime() - t0) + 'ms');
    }
  }

  async loadForumData(): Promise<Dict | null> {
    try {
      const d = await new Promise<Dict>((resolve, reject) => {
        this.api.forumRecommend({
          onSuccess: (d) => resolve(d),
          onError: (code, msg) => reject({ code, msg })
        });
      });
      const inner = (d.data as Dict) || d;
      console.info('TiebaLite: forumRecommend keys=' + Object.keys(d).join(',') + ' dataKeys=' + Object.keys(inner).join(','));
      return d;
    } catch (e) {
      console.info('TiebaLite: forumRecommend failed, trying userLikeForum');
      try {
        const account = AccountManager.getInstance().getCurrentAccountSync();
        if (!account) return null;
        const uid = Number(account.uid || 0);
        if (!uid) return null;
        return await new Promise<Dict>((resolve, reject) => {
          this.api.userLikeForum(uid, 1, {
            onSuccess: (d) => resolve(d),
            onError: (code, msg) => reject({ code, msg })
          });
        });
      } catch (e2) {
        console.error('TiebaLite: userLikeForum also failed: ' + String(e2));
        try {
          return await new Promise<Dict>((resolve, reject) => {
            this.api.forumRecommendNew(0, {
              onSuccess: (d) => resolve(d),
              onError: (code, msg) => reject({ code, msg })
            });
          });
        } catch (e3) {
          console.error('TiebaLite: all forum APIs failed: ' + String(e3));
          return null;
        }
        }
      }

  }

  private unsignedSignCount(): number {
    if (!this.isLoggedIn) return 0;
    const appSigned = new Set<number>();
    for (const v of this.signedIdsArr) {
      const n = Number(v);
      if (n > 0) appSigned.add(n);
    }
    let count = 0;
    for (const forum of this.followedForums) {
      const forumId = Number((forum as Dict).id || (forum as Dict).forum_id || (forum as Dict).forumId || 0);
      if (forumId > 0 && !this.signedForumIds.has(forumId) && !appSigned.has(forumId)) {
        count++;
      }
    }
    return count;
  }

  async doOneClickSign(): Promise<void> {
    if (this.signing) return;
    this.signing = true;
    try {
      if (!AccountManager.getInstance().isLoggedIn() || this.followedForums.length === 0) {
        promptAction.showToast({ message: '暂无关注的贴吧', duration: 2000 });
        return;
      }
      const repo = ForumRepository.getInstance();
      const newSet = new Set(this.signedForumIds);
      let successCount = 0;
      const tasks: Promise<void>[] = [];
      for (const forum of this.followedForums) {
        const forumId = Number((forum as Dict).id || (forum as Dict).forum_id || (forum as Dict).forumId || 0);
        if (forumId <= 0) continue;
        if (this.signedForumIds.has(forumId)) { successCount++; continue; }
        const forumName = getStr(forum, 'name', 'forumName', 'forum_name') || '';
        tasks.push(repo.signForum(forumId, forumName).then(() => {
          successCount++;
          newSet.add(forumId);
        }).catch(() => {}));
      }
      await Promise.all(tasks);
      this.signedForumIds = newSet;
      const arrVal: number[] = [];
      newSet.forEach((v: number) => { arrVal.push(v); });
      AppStorage.Set<Object[]>('signedForumIdsArr', arrVal as Object[]);
      if (successCount > 0) {
        promptAction.showToast({ message: '签到成功 ✓' + successCount + '个', duration: 2000 });
      } else {
        promptAction.showToast({ message: '签到失败，请重试', duration: 2000 });
      }
    } catch (e) {
      console.error('TiebaLite: one-click sign error=' + String(e));
      promptAction.showToast({ message: '签到失败，请重试', duration: 2000 });
    } finally {
      this.signing = false;
    }
  }

  build() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor(this.bgColor)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      Column() {
      if (!this.isLoggedIn) {
        Row() {
          Image($r('app.media.ic_search')).width(Math.round(16 * this.fontScale)).height(Math.round(16 * this.fontScale)).fillColor(textTertiary(this.isDark)).margin({ left: 16 })
          Text(' 搜索贴吧...')
            .fontFamily(this.appFontFamily).fontSize(14 * this.fontScale).fontColor(textTertiary(this.isDark))
          Blank()
        }
        .width('93%').height(44).backgroundColor(blendWithBg(this.primaryColor, 0.15, this.isDark, '#1E1E1E')).borderRadius(Math.max(0, Math.round(22 * this.searchBoxRound / 100)))
        .border({ width: 1, color: dividerColor(this.isDark) })
        .margin({ top: 16, bottom: 8 })
        .shadow({ radius: 2, color: shadowColor(this.isDark), offsetY: 1 })
        .onClick(() => { NavigationHelper.navigate('pages/search/SearchPage'); })

        this.RecentForumsRow()
      }

      if (this.loading) {
        LoadingState({ message: '加载中...' })
      } else if (!this.isLoggedIn) {
        this.GuestView()
      } else if (this.error.length > 0) {
        ErrorState({ message: this.error, onRetryAction: (): void => { void this.loadData(); } })
      } else {
        if (this.reduceEffects) {
          PullToRefresh({
            reduceEffects: true,
            scroller: this.recentScroller,
            iconTopOffset: 100,
            isRefreshing: this.isRefreshing,
            onRefresh: (): void => { this.isRefreshing = true; },
            onTimeout: (): void => { this.isRefreshing = false; }
          }) {
            this.homeScrollContent()
          }
        } else {
          PullToRefresh({
            scroller: this.recentScroller,
            iconTopOffset: 100,
            isRefreshing: this.isRefreshing,
            onRefresh: (): void => { this.isRefreshing = true; },
            onTimeout: (): void => { this.isRefreshing = false; }
          }) {
            this.homeScrollContent()
          }
        }
      }

        if (this.isLoggedIn) {
          Column() {
            Row() {
              Avatar({ portrait: buildPortraitUrl(this.accountPortrait), avatarSize: 36, defaultName: this.accountName })
                .margin({ left: 12 })
                .onClick(() => {
                  this.allAccounts = AccountManager.getInstance().getAllAccounts();
                  this.showAccountMenu = !this.showAccountMenu;
                })
              Text(this.accountName).fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark)).margin({ left: 8 })
                .onClick(() => {
                  const acct = AccountManager.getInstance().getCurrentAccountSync();
                  if (acct && acct.uid > 0) NavigationHelper.navigate('pages/user/UserProfilePage', { uid: String(acct.uid) });
                })
              Blank()
              if (this.signing) {
                Text('签到中...').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor('#22AA22').margin({ right: 10 })
                  .onClick(() => { this.doOneClickSign(); })
              } else {
                Stack({ alignContent: Alignment.TopEnd }) {
                  Image($r('app.media.ic_check')).width(Math.round(20 * this.fontScale)).height(Math.round(20 * this.fontScale)).fillColor((this.signedForumIds.size > 0 || this.signedIdsArr.length > 0) ? '#22AA22' : textTertiary(this.isDark))
                    .onClick(() => { this.doOneClickSign(); })
                  if (this.signBadge && this.unsignedSignCount() > 0) {
                    Text(this.unsignedSignCount() > 99 ? '99+' : String(this.unsignedSignCount()))
                      .fontFamily(this.appFontFamily).fontSize(10).fontColor('#FFFFFF')
                      .backgroundColor('#FF4444').borderRadius(8)
                      .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                      .textAlign(TextAlign.Center)
                  }
                }
                .margin({ right: 10 })
                .onClick(() => { this.doOneClickSign(); }, 12)
              }
              if (this.listMode) {
                Image($r('app.media.ic_menu_list')).width(Math.round(20 * this.fontScale)).height(Math.round(20 * this.fontScale)).fillColor('#4477E0').margin({ right: 14 })
                  .onClick(() => { this.listMode = !this.listMode; AppStorage.Set<boolean>('homeListMode', this.listMode); })
              } else {
                Image($r('app.media.ic_menu_grid')).width(Math.round(20 * this.fontScale)).height(Math.round(20 * this.fontScale)).fillColor('#4477E0').margin({ right: 14 })
                  .onClick(() => { this.listMode = !this.listMode; AppStorage.Set<boolean>('homeListMode', this.listMode); })
              }
            }
            .width('100%').height(52).alignItems(VerticalAlign.Center)
            Row() {
              Image($r('app.media.ic_search')).width(Math.round(16 * this.fontScale)).height(Math.round(16 * this.fontScale)).fillColor(textTertiary(this.isDark)).margin({ left: 16 })
              Text(' 搜索贴吧...')
                .fontFamily(this.appFontFamily).fontSize(14 * this.fontScale).fontColor(textTertiary(this.isDark))
              Blank()
            }
            .width('93%').height(44).backgroundColor(blendWithBg(this.primaryColor, 0.15, this.isDark, '#1E1E1E')).borderRadius(Math.max(0, Math.round(22 * this.searchBoxRound / 100)))
            .border({ width: 1, color: dividerColor(this.isDark) })
            .margin({ top: 4, bottom: 8 })
            .shadow({ radius: 2, color: shadowColor(this.isDark), offsetY: 1 })
            .onClick(() => { NavigationHelper.navigate('pages/search/SearchPage'); })
          }
          .width('100%')
          .backgroundColor(this.cardStyle === 1 ? withAlpha((this.cardStyle === 1 ? darkenColor(this.bgColor, this.headerTint / 100) : this.bgColor), 1 - this.headerAlpha / 100) : withAlpha(this.bgColor, 1 - this.headerAlpha / 100))
          .backdropBlur(60)
          .border({ width: { bottom: 1 }, color: blendWithBg(this.primaryColor, 0.15, this.isDark, '#1E1E1E') })
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
          .position({ x: 0, y: 0 })
          .zIndex(2)
        }
      }
      .width('100%').height('100%').justifyContent(FlexAlign.Start).backgroundColor(this.bgColor).expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
      if (this.showAccountMenu) {
        Column().width('100%').height('100%').onClick(() => { this.showAccountMenu = false; })
        Column() {
          Column() {
            ForEach(this.allAccounts, (account: Account) => {
              Row() {
                Avatar({ portrait: account.portrait, avatarSize: 32, defaultName: account.nickname || account.name })
                Column() {
                  Text(account.nickname || account.name).fontFamily(this.appFontFamily).fontSize(14).fontColor(textPrimary(this.isDark)).maxLines(1)
                  Text('ID: ' + account.name).fontFamily(this.appFontFamily).fontSize(11).fontColor(textTertiary(this.isDark))
                }
                .layoutWeight(1).margin({ left: 8 }).alignItems(HorizontalAlign.Start)
                if (this.isCurrentAccount(account)) {
                  Image($r('app.media.ic_check')).width(18).height(18).fillColor(this.primaryColor)
                }
              }
              .width('100%').height(48).padding({ left: 12, right: 12 })
              .onClick(() => {
                AccountManager.getInstance().setCurrentAccount(account);
                this.showAccountMenu = false;
                AppStorage.Set<boolean>('homeInitialLoadDone', false);
                this.aboutToAppear();
              })
            })
          }
          .width('100%').backgroundColor(blendWithBg(this.primaryColor, 0.08, this.isDark))

          Row() {
            Image($r('app.media.ic_add')).width(18).height(18).fillColor(this.primaryColor)
            Text('添加账号').fontFamily(this.appFontFamily).fontSize(14).fontColor(textAccent(this.primaryColor, this.isDark))
          }
          .width('100%').height(40).justifyContent(FlexAlign.Center).backgroundColor(blendWithBg(this.primaryColor, 0.08, this.isDark))
            .onClick(() => {
              this.showAccountMenu = false;
              NavigationHelper.navigate('pages/login/LoginPage');
            })

          Text('账号管理 >').fontFamily(this.appFontFamily).fontSize(13).fontColor(textSecondary(this.isDark)).width('100%').height(36)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.showAccountMenu = false;
              NavigationHelper.navigate('pages/settings/AccountManagePage');
            })
        }
          .width('100%').backgroundColor(cardBg(this.isDark)).borderRadius(8)
        .shadow({ radius: 8, color: shadowColor(this.isDark), offsetY: 4 })
        .position({ top: 52 })
      }
      if (this.showForumMenu) { this.ContextMenuOverlay() }
      }
    .width('100%').height('100%').backgroundColor(this.bgColor).expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    
  }

  @Builder
  homeScrollContent() {
        Scroll(this.recentScroller) {
            Column() {
              Blank().height(108)
              this.RecentForumsRow()
              if (this.followedForums.length > 0) {
                if (this.getPinnedForums().length > 0) {
                  Column() {
                    Row() {
                      Text('置顶吧').fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark))
                      Blank()
                      Text(String(this.getPinnedForums().length)).fontFamily(this.appFontFamily).fontSize(11).fontColor(textTertiary(this.isDark)).margin({ right: 4 })
                    }
                    .width('100%').padding({ left: 16, right: 16, top: 5, bottom: 4 })

                    Column() {
                      if (this.listMode) {
                        ForEach(this.chunkForums(this.getPinnedForums()), (pair: Dict[], rowIdx: number) => {
                          Row() {
                            ForEach(pair, (forum: Dict, colIdx: number) => {
                              Row() {
                                Avatar({ portrait: buildPortraitUrl(getStr(forum, 'avatar', 'forumAvatar')), avatarSize: 28, defaultName: getStr(forum, 'name', 'forumName', 'forum_name') })
                                Text(getStr(forum, 'name', 'forumName', 'forum_name'))
                                  .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(textPrimary(this.isDark)).maxLines(1)
                                  .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1).margin({ left: 6 })
                                if (this.signedForumIds.has(Number((forum as Dict).id || (forum as Dict).forum_id || (forum as Dict).forumId || 0))) {
                                  Image($r('app.media.ic_check')).width(Math.round(12 * this.fontScale)).height(Math.round(12 * this.fontScale)).fillColor('#22AA22').margin({ right: 4 })
                                }
                                Text('Lv.' + getNum(forum, 'level', 'level_id', 'user_level', 'forum_level'))
                                  .fontFamily(this.appFontFamily).fontSize(Math.round(10 * this.fontScale)).fontColor(this.getLevelColor(getNum(forum, 'level', 'level_id', 'user_level', 'forum_level'))).fontWeight(FontWeight.Bold)
                                  .padding({ left: 4, right: 4, top: 1, bottom: 1 }).backgroundColor(blendWithBg(this.getLevelColor(getNum(forum, 'level', 'level_id', 'user_level', 'forum_level')), 0.15, this.isDark)).borderRadius(6)
                              }
                              .layoutWeight(1).height(52).padding({ left: colIdx === 0 ? 16 : 8, right: colIdx === 0 ? 8 : 16 }).alignItems(VerticalAlign.Center)
                              .gesture(GestureGroup(GestureMode.Exclusive,
                                TapGesture({ distanceThreshold: 12 }).onAction(() => {
                                  this.saveRecentForum(forum);
                                  NavigationHelper.navigate('pages/forum/ForumPage', { forumName: getStr(forum, 'name', 'forumName', 'forum_name'), forumId: getStr(forum, 'id', 'forum_id', 'forumId') });
                                }),
                                LongPressGesture({ repeat: false, duration: 400 })
                                  .onAction((event?: GestureEvent) => {
                                    this.contextMenuForum = forum;
                                    if (event && event.fingerList && event.fingerList.length > 0) {
                                      this.contextMenuX = event.fingerList[0].globalX;
                                      this.contextMenuY = event.fingerList[0].globalY;
                                    }
                                    this.showForumMenu = true;
                                  })
                              ))
                              if (colIdx === 0 && pair.length > 1) {
                                Column().width(0.5).height(36).backgroundColor(blendWithBg(this.primaryColor, 0.20, this.isDark, '#1E1E1E'))
                              }
                            })
                            if (pair.length === 1) {
                              Column().layoutWeight(1)
                            }
                          }
                          .width('100%').height(56)
                          if (rowIdx < this.chunkForums(this.getPinnedForums()).length - 1) {
                            Divider().height(0.5).color(blendWithBg(this.primaryColor, 0.15, this.isDark, '#1E1E1E')).margin({ left: 16, right: 16 })
                          }
                        })
                      } else {
                        ForEach(this.getPinnedForums(), (forum: Dict, idx: number) => {
                          Row() {
                            Avatar({ portrait: buildPortraitUrl(getStr(forum, 'avatar', 'forumAvatar')), avatarSize: 36, defaultName: getStr(forum, 'name', 'forumName', 'forum_name') })
                            Text(getStr(forum, 'name', 'forumName', 'forum_name'))
                              .fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontColor(textPrimary(this.isDark)).margin({ left: 10 }).layoutWeight(1)
                            if (this.signedForumIds.has(Number((forum as Dict).id || (forum as Dict).forum_id || (forum as Dict).forumId || 0))) {
                              Image($r('app.media.ic_check')).width(Math.round(14 * this.fontScale)).height(Math.round(14 * this.fontScale)).fillColor('#22AA22').margin({ right: 2 })
                            }
                            Text('Lv.' + getNum(forum, 'level', 'level_id', 'user_level', 'forum_level'))
                              .fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(this.getLevelColor(getNum(forum, 'level', 'level_id', 'user_level', 'forum_level'))).fontWeight(FontWeight.Bold)
                              .padding({ left: 5, right: 5, top: 1, bottom: 1 }).backgroundColor(blendWithBg(this.getLevelColor(getNum(forum, 'level', 'level_id', 'user_level', 'forum_level')), 0.15, this.isDark)).borderRadius(8).margin({ right: 8 })
                          }
                          .width('100%').height(52).padding({ left: 16, right: 16 })
                          .gesture(GestureGroup(GestureMode.Exclusive,
                            TapGesture({ distanceThreshold: 12 }).onAction(() => {
                              this.saveRecentForum(forum);
                              NavigationHelper.navigate('pages/forum/ForumPage', { forumName: getStr(forum, 'name', 'forumName', 'forum_name'), forumId: getStr(forum, 'id', 'forum_id', 'forumId') });
                            }),
                            LongPressGesture({ repeat: false, duration: 400 })
                              .onAction((event?: GestureEvent) => {
                                this.contextMenuForum = forum;
                                if (event && event.fingerList && event.fingerList.length > 0) {
                                  this.contextMenuX = event.fingerList[0].globalX;
                                  this.contextMenuY = event.fingerList[0].globalY;
                                }
                                this.showForumMenu = true;
                              })
                          ))
                          if (idx < this.getPinnedForums().length - 1) {
                            Divider().height(0.5).color(blendWithBg(this.primaryColor, 0.15, this.isDark, '#1E1E1E')).margin({ left: 62 })
                          }
                        })
                      }
                    }
                    .width('100%').backgroundColor(blendWithBg(this.primaryColor, 0.04, this.isDark, '#1E1E1E'))                  }
                  .width('100%').margin({ top: 4 })
                }

                Column() {
                  Row() {
                    Text('我的贴吧').fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark))
                  }
                  .width('100%').padding({ left: 16, right: 16, top: 5, bottom: 4 })

                  Column() {
                    if (this.listMode) {
                      ForEach(this.chunkForums(this.getUnpinnedForums()), (pair: Dict[], rowIdx: number) => {
                        Row() {
                          ForEach(pair, (forum: Dict, colIdx: number) => {
                            Row() {
                              Avatar({ portrait: buildPortraitUrl(getStr(forum, 'avatar', 'forumAvatar')), avatarSize: 28, defaultName: getStr(forum, 'name', 'forumName', 'forum_name') })
                              Text(getStr(forum, 'name', 'forumName', 'forum_name'))
                                .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(textPrimary(this.isDark)).maxLines(1)
                                .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1).margin({ left: 6 })
                              if (this.signedForumIds.has(Number((forum as Dict).id || (forum as Dict).forum_id || (forum as Dict).forumId || 0))) {
                                Image($r('app.media.ic_check')).width(Math.round(12 * this.fontScale)).height(Math.round(12 * this.fontScale)).fillColor('#22AA22').margin({ right: 4 })
                              }
                              Text('Lv.' + getNum(forum, 'level', 'level_id', 'user_level', 'forum_level'))
                                .fontFamily(this.appFontFamily).fontSize(Math.round(10 * this.fontScale)).fontColor(this.getLevelColor(getNum(forum, 'level', 'level_id', 'user_level', 'forum_level'))).fontWeight(FontWeight.Bold)
                                .padding({ left: 4, right: 4, top: 1, bottom: 1 }).backgroundColor(blendWithBg(this.getLevelColor(getNum(forum, 'level', 'level_id', 'user_level', 'forum_level')), 0.15, this.isDark)).borderRadius(6)
                            }
                            .layoutWeight(1).height(52).padding({ left: colIdx === 0 ? 16 : 8, right: colIdx === 0 ? 8 : 16 }).alignItems(VerticalAlign.Center)
                            .gesture(GestureGroup(GestureMode.Exclusive,
                              TapGesture({ distanceThreshold: 12 }).onAction(() => {
                                this.saveRecentForum(forum);
                                NavigationHelper.navigate('pages/forum/ForumPage', { forumName: getStr(forum, 'name', 'forumName', 'forum_name'), forumId: getStr(forum, 'id', 'forum_id', 'forumId') });
                              }),
                              LongPressGesture({ repeat: false, duration: 400 })
                                .onAction((event?: GestureEvent) => {
                                  this.contextMenuForum = forum;
                                  if (event && event.fingerList && event.fingerList.length > 0) {
                                    this.contextMenuX = event.fingerList[0].globalX;
                                    this.contextMenuY = event.fingerList[0].globalY;
                                  }
                                  this.showForumMenu = true;
                                })
                            ))
                            if (colIdx === 0 && pair.length > 1) {
                              Column().width(0.5).height(36).backgroundColor(blendWithBg(this.primaryColor, 0.20, this.isDark, '#1E1E1E'))
                            }
                          })
                          if (pair.length === 1) {
                            Column().layoutWeight(1)
                          }
                        }
                        .width('100%').height(56)
                        if (rowIdx < this.chunkForums(this.getUnpinnedForums()).length - 1) {
                          Divider().height(0.5).color(blendWithBg(this.primaryColor, 0.15, this.isDark, '#1E1E1E')).margin({ left: 16, right: 16 })
                        }
                      })
                    } else {
                      ForEach(this.getUnpinnedForums(), (forum: Dict, idx: number) => {
                        Row() {
                          Avatar({ portrait: buildPortraitUrl(getStr(forum, 'avatar', 'forumAvatar')), avatarSize: 36, defaultName: getStr(forum, 'name', 'forumName', 'forum_name') })
                          Text(getStr(forum, 'name', 'forumName', 'forum_name'))
                            .fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontColor(textPrimary(this.isDark)).margin({ left: 10 }).layoutWeight(1)
                          if (this.signedForumIds.has(Number((forum as Dict).id || (forum as Dict).forum_id || (forum as Dict).forumId || 0))) {
                            Image($r('app.media.ic_check')).width(Math.round(14 * this.fontScale)).height(Math.round(14 * this.fontScale)).fillColor('#22AA22').margin({ right: 2 })
                          }
Text('Lv.' + getNum(forum, 'level', 'level_id', 'user_level', 'forum_level'))
                          .fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(this.getLevelColor(getNum(forum, 'level', 'level_id', 'user_level', 'forum_level'))).fontWeight(FontWeight.Bold)
                          .padding({ left: 5, right: 5, top: 1, bottom: 1 }).backgroundColor(blendWithBg(this.getLevelColor(getNum(forum, 'level', 'level_id', 'user_level', 'forum_level')), 0.15, this.isDark)).borderRadius(8).margin({ right: 8 })
                        }
                        .width('100%').height(52).padding({ left: 16, right: 16 })
                        .gesture(GestureGroup(GestureMode.Exclusive,
                          TapGesture({ distanceThreshold: 12 }).onAction(() => {
                            this.saveRecentForum(forum);
                            NavigationHelper.navigate('pages/forum/ForumPage', { forumName: getStr(forum, 'name', 'forumName', 'forum_name'), forumId: getStr(forum, 'id', 'forum_id', 'forumId') });
                          }),
                          LongPressGesture({ repeat: false, duration: 400 })
                            .onAction((event?: GestureEvent) => {
                              this.contextMenuForum = forum;
                              if (event && event.fingerList && event.fingerList.length > 0) {
                                this.contextMenuX = event.fingerList[0].globalX;
                                this.contextMenuY = event.fingerList[0].globalY;
                              }
                              this.showForumMenu = true;
                            })
                        ))
                        if (idx < this.getUnpinnedForums().length - 1) {
                          Divider().height(0.5).color(blendWithBg(this.primaryColor, 0.15, this.isDark, '#1E1E1E')).margin({ left: 62 })
                        }
                      })
                    }
                  }
                  .width('100%').backgroundColor(blendWithBg(this.primaryColor, 0.04, this.isDark, '#1E1E1E'))
                }
                .width('100%').margin({ top: 6 })
              }

              if (this.listMode) {
                ForEach(this.feedData, (thread: Dict, index: number) => {
                  ThreadCard({
                    thread: thread,
                    onCardClick: () => {
                      NavigationHelper.navigate('pages/thread/ThreadPage', {
                        threadId: getStr(thread, 'id', 'tid', 'threadId', 'thread_id'),
                        forumId: getStr(thread, 'forumId', 'forum_id'),
                        forumName: this.getForumName(thread)
                      });
                    },
                    onForumClick: () => {
                      this.saveRecentForum({ name: this.getForumName(thread), id: getStr(thread, 'forumId', 'forum_id') });
                      NavigationHelper.navigate('pages/forum/ForumPage', {
                        forumName: this.getForumName(thread), forumId: getStr(thread, 'forumId', 'forum_id')
                      });
                    },
                    onLikeClick: (liked: boolean) => {
                      const tid = getStr(thread, 'id', 'tid', 'threadId', 'thread_id');
                      if (tid) {

                        const repo = PbPageRepository.getInstance();

                        if (liked) repo.likePost(Number(tid), 0).catch(() => {});

                        else repo.dislikePost(Number(tid), 0).catch(() => {});

                      }
                    }
                  }).margin({ left: 16, right: 16, top: 6, bottom: 6 })
                }, (thread: Dict) => getStr(thread, 'id', 'tid', 'threadId', 'thread_id'))
              } else {
                Row() {
                  Column() {
                    ForEach(this.getLeftColumnThreads(), (thread: Dict, index: number) => {
                      ThreadCard({
                        thread: thread,
                    onCardClick: () => {
                      NavigationHelper.navigate('pages/thread/ThreadPage', {
                        threadId: getStr(thread, 'id', 'tid', 'threadId', 'thread_id'),
                        forumId: getStr(thread, 'forumId', 'forum_id'),
                        forumName: this.getForumName(thread)
                      });
                    },
                    onForumClick: () => {
                      this.saveRecentForum({ name: this.getForumName(thread), id: getStr(thread, 'forumId', 'forum_id') });
                      NavigationHelper.navigate('pages/forum/ForumPage', {
                        forumName: this.getForumName(thread), forumId: getStr(thread, 'forumId', 'forum_id')
                      });
                    },
                    onLikeClick: (liked: boolean) => {
                      const tid = getStr(thread, 'id', 'tid', 'threadId', 'thread_id');
                      if (tid) {

                        const repo = PbPageRepository.getInstance();

                        if (liked) repo.likePost(Number(tid), 0).catch(() => {});

                        else repo.dislikePost(Number(tid), 0).catch(() => {});

                      }
                    }
                  }).margin({ left: 4, right: 2, bottom: 8 })
                    }, (thread: Dict) => getStr(thread, 'id', 'tid', 'threadId', 'thread_id'))
                  }.layoutWeight(1)
                  Column() {
                    ForEach(this.getRightColumnThreads(), (thread: Dict, index: number) => {
                      ThreadCard({
                        thread: thread,
                    onCardClick: () => {
                      NavigationHelper.navigate('pages/thread/ThreadPage', {
                        threadId: getStr(thread, 'id', 'tid', 'threadId', 'thread_id'),
                        forumId: getStr(thread, 'forumId', 'forum_id'),
                        forumName: this.getForumName(thread)
                      });
                    },
                    onForumClick: () => {
                      this.saveRecentForum({ name: this.getForumName(thread), id: getStr(thread, 'forumId', 'forum_id') });
                      NavigationHelper.navigate('pages/forum/ForumPage', {
                        forumName: this.getForumName(thread), forumId: getStr(thread, 'forumId', 'forum_id')
                      });
                    },
                    onLikeClick: (liked: boolean) => {
                      const tid = getStr(thread, 'id', 'tid', 'threadId', 'thread_id');
                      if (tid) {

                        const repo = PbPageRepository.getInstance();

                        if (liked) repo.likePost(Number(tid), 0).catch(() => {});

                        else repo.dislikePost(Number(tid), 0).catch(() => {});

                      }
                    }
                  }).margin({ left: 2, right: 4, bottom: 8 })
                    }, (thread: Dict) => getStr(thread, 'id', 'tid', 'threadId', 'thread_id'))
                  }.layoutWeight(1)
                }
                .width('100%').padding({ left: 16, right: 16 })
                }
            }
            .width('100%')
            .padding({ bottom: 66 })
            .backgroundColor(blendWithBg(this.primaryColor, 0.04, this.isDark, '#1E1E1E'))
          }
            .scrollBar(BarState.Off)
          .width('100%').layoutWeight(1)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
          .backgroundColor(this.bgColor)
          .edgeEffect(EdgeEffect.None)
          .onReachEnd(() => {
            if (this.hasMore && !this.loading) { this.page++; this.loadMore(); }
          })
        }
  @Builder
  RecentForumsRow() {
    if (this.showRecentForums && this.getRecentForums().length > 0 && !this.loading) {
      Row() {
        Image($r('app.media.ic_footprint')).width(Math.round(16 * this.fontScale)).height(Math.round(16 * this.fontScale)).fillColor(textPrimary(this.isDark)).margin({ left: 16 })
        Text('最近')
          .fontFamily(this.appFontFamily).fontSize(Math.round(13 * this.fontScale)).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark))
        Scroll() {
          Row() {
            ForEach(this.getRecentForums().slice(0, 15), (forum: Dict) => {
              Row() {
                Text(getStr(forum, 'name', 'forumName', 'forum_name'))
                  .fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textPrimary(this.isDark))
                if (this.pendingDeleteForumId === getStr(forum, 'id')) {
                  Image($r('app.media.ic_close')).width(Math.round(12 * this.fontScale)).height(Math.round(12 * this.fontScale)).fillColor('#FF4444').margin({ left: 4 })
                    .onClick(() => {
                      this.removeRecentForum(forum);
                      this.pendingDeleteForumId = '';
                    })
                }
              }
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor(blendWithBg(this.primaryColor, 0.13, this.isDark, '#1E1E1E')).borderRadius(12)
              .margin({ left: 8 })
              .gesture(GestureGroup(GestureMode.Exclusive,
                TapGesture({ distanceThreshold: 12 }).onAction(() => {
                  this.saveRecentForum(forum);
                  NavigationHelper.navigate('pages/forum/ForumPage', { forumName: getStr(forum, 'name', 'forumName', 'forum_name'), forumId: getStr(forum, 'id', 'forum_id', 'forumId') });
                }),
                LongPressGesture({ repeat: false, duration: 500 })
                  .onAction(() => {
                    this.pendingDeleteForumId = this.pendingDeleteForumId === getStr(forum, 'id') ? '' : getStr(forum, 'id');
                  })
              ))
            })
          }.height('100%')
        }
          .scrollBar(BarState.Off)
        .scrollable(ScrollDirection.Horizontal).scrollBarWidth(0).layoutWeight(1).height('100%')
        .margin({ left: 4, right: 12 })
        Blank()
      }
      .width('100%').height(44).alignItems(VerticalAlign.Center).margin({ top: 2, bottom: 3 })
    }
  }

  @Builder
  GuestView() {
    Column() {
      Column() {
        Text('你尚未登录').fontFamily(this.appFontFamily).fontSize(Math.round(22 * this.fontScale)).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark)).margin({ top: 60 })
        Text('请登录之后查看你的关注。\n或者你也可以先去逛逛发现？').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark)).margin({ top: 8 })
        Row() {
          Button('登录').fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontColor('#FFFFFF').backgroundColor('#4477E0').borderRadius(22).height(44).layoutWeight(1)
            .onClick(() => { NavigationHelper.navigate('pages/login/LoginPage'); })
          Button('随便看看').fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontColor('#4477E0').backgroundColor(blendWithBg(this.primaryColor, 0.12, this.isDark, '#1E1E1E')).borderRadius(22).height(44).layoutWeight(1).margin({ left: 12 })
            .onClick(() => { NavigationHelper.navigate('pages/ExplorePageWrapper', { initialTab: 2 }); })
        }
        .width('80%').margin({ top: 24 })
      }
      .width('100%').alignItems(HorizontalAlign.Center).layoutWeight(1)
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start).backgroundColor(blendWithBg(this.primaryColor, 0.08, this.isDark)).expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  private getAdjustedMenuX(): number {
    const menuWidth = 100;
    if (this.contextMenuX < this.screenWidth / 2) {
      const x = this.contextMenuX - menuWidth / 2;
      return Math.max(0, Math.min(this.screenWidth - menuWidth, x));
    } else {
      return Math.max(0, Math.min(this.screenWidth - menuWidth, this.contextMenuX - menuWidth));
    }
  }

  private getAdjustedMenuY(): number {
    const menuHeight = 180;
    return Math.max(0, Math.min(this.screenHeight - menuHeight, this.contextMenuY - menuHeight));
  }

  @Builder
  ContextMenuOverlay() {
    Column() {
      Column() {
        if (this.contextMenuForum) {
          Text(getStr(this.contextMenuForum, 'name', 'forumName', 'forum_name'))
            .fontFamily(this.appFontFamily).fontSize(14).fontColor(textPrimary(this.isDark)).fontWeight(FontWeight.Bold)
            .padding({ left: 16, right: 16, top: 12, bottom: 8 })
          if (this.isForumPinned(this.contextMenuForum)) {
            this.MenuItem('取消置顶', () => { this.unpinForum(this.contextMenuForum!); this.showForumMenu = false; })
          } else {
            this.MenuItem('置顶', () => { this.pinForum(this.contextMenuForum!); this.showForumMenu = false; })
          }
          this.MenuItem('复制吧名', () => { this.copyForumName(this.contextMenuForum!); this.showForumMenu = false; })
          this.MenuItem('取消关注', () => { this.unfollowForum(this.contextMenuForum!); this.showForumMenu = false; })
        }
      }
      .backgroundColor(cardBg(this.isDark)).borderRadius(12)
      .shadow({ radius: 16, color: shadowColor(this.isDark), offsetY: 8 })
      .position({ x: this.getAdjustedMenuX(), y: this.getAdjustedMenuY() })
    }
    .width('100%').height('100%')
    .alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Start)
    .backgroundColor('#33000000')
    .onClick(() => { this.showForumMenu = false; })
  }

  @Builder
  MenuItem(label: string, action: () => void) {
    Row() {
      Text(label).fontFamily(this.appFontFamily).fontSize(15).fontColor(textPrimary(this.isDark))
    }
    .height(44).padding({ left: 16, right: 16 })
    .onClick(() => { action(); })
    .backgroundColor(cardBg(this.isDark))
  }

  private chunkForums(arr: Dict[]): Dict[][] {
    const result: Dict[][] = [];
    for (let i = 0; i < arr.length; i += 2) {
      result.push(arr.slice(i, i + 2));
    }
    return result;
  }

  private chunkThreads(arr: Dict[]): Dict[][] {
    const result: Dict[][] = [];
    for (let i = 0; i < arr.length; i += 2) {
      result.push(arr.slice(i, i + 2));
    }
    return result;
  }

  private getLeftColumnThreads(): Dict[] {
    const result: Dict[] = [];
    for (let i = 0; i < this.feedData.length; i += 2) result.push(this.feedData[i]);
    return result;
  }

  private getRightColumnThreads(): Dict[] {
    const result: Dict[] = [];
    for (let i = 1; i < this.feedData.length; i += 2) result.push(this.feedData[i]);
    return result;
  }

  private getForumName(thread: Dict): string {
    const fi = thread.forumInfo as Dict | undefined;
    if (fi) return getStr(fi, 'name', 'forumName', 'forum_name');
    const fn = thread.forumName || thread.forum_name;
    if (typeof fn === 'string') return fn;
    if (fn && typeof fn === 'object') return getStr(fn as Dict, 'name', 'forumName', 'forum_name');
    const forum = thread.forum as Dict | undefined;
    if (forum) return getStr(forum, 'name', 'forumName', 'forum_name');
    const fname = getStrObj(thread, 'fname', 'forum_name', 'forumName', 'forum');
    if (fname && typeof fname !== 'object') return fname;
    return '';
  }

  async loadMore(): Promise<void> {
    try {
      const more: Dict = await HomeRepository.getInstance().loadHomeFeed(this.page);
      const threads = this.extractThreads(more);
      if (threads.length === 0) { this.hasMore = false; return; }
      const existingIds = new Set(this.feedData.map(t => getStr(t, 'id', 'tid', 'threadId', 'thread_id')));
      const uniqueNew = threads.filter(t => !existingIds.has(getStr(t, 'id', 'tid', 'threadId', 'thread_id')));
      if (uniqueNew.length === 0) { this.hasMore = false; return; }
      this.feedData = [...this.feedData, ...uniqueNew];
    } catch (e) { this.hasMore = false; }
  }

  private extractThreads(data: Dict): Dict[] {
    if (!data) return [];
    const d = (data.data as Dict) || data;
    let threads: Dict[] = [];
    if (d.thread_list && (d.thread_list as Dict[]).length > 0) threads = d.thread_list as Dict[];
    else if (d.thread_info && (d.thread_info as Dict[]).length > 0) threads = d.thread_info as Dict[];
    else if (d.post_list && (d.post_list as Dict[]).length > 0) threads = d.post_list as Dict[];
    else if (Array.isArray(data)) threads = data as Dict[];
    else if (Array.isArray(d)) threads = d as Dict[];
    const normalized: Dict[] = [];
    if (threads.length > 0) {
      for (const item of threads) {
        const inner = item.threadList || item.thread_list;
        let t: Dict = item;
        if (inner && Array.isArray(inner) && inner.length > 0) {
          const innerItem = inner[0] as Dict;
          if ((innerItem as Dict)['media'] === undefined && (item as Dict)['media'] !== undefined)
            (innerItem as Dict)['media'] = (item as Dict)['media'];
          if ((innerItem as Dict)['imageUrls'] === undefined && (item as Dict)['imageUrls'] !== undefined)
            (innerItem as Dict)['imageUrls'] = (item as Dict)['imageUrls'];
          if ((innerItem as Dict)['firstPostContent'] === undefined && (item as Dict)['firstPostContent'] !== undefined)
            (innerItem as Dict)['firstPostContent'] = (item as Dict)['firstPostContent'];
          if ((innerItem as Dict)['first_post_content'] === undefined && (item as Dict)['first_post_content'] !== undefined)
            (innerItem as Dict)['first_post_content'] = (item as Dict)['first_post_content'];
          t = innerItem;
        }
        normalized.push(t);
      }
    } else {
      console.info('TiebaLite: extractThreads no match, keys=' + Object.keys(d).join(','));
      return [];
    }
    const blockRepo = BlockRepository.getInstance();
    return normalized.filter((t: Dict) => {
      const forumName = this.getForumName(t);
      const author = t.author as Dict | undefined;
      const uid = Number((author ? getStr(author, 'id', 'user_id', 'uid') : '') || getStr(t, 'authorId', 'author_id', 'authorUid', 'author_uid', 'uid', 'userId', 'user_id') || 0);
      const abs = t._abstract;
      let abstractStr = '';
      if (Array.isArray(abs) && abs.length > 0) {
        const parts: string[] = [];
        for (const it of abs as Dict[]) {
          const c = getStr(it, 'c', 'text');
          if (c) parts.push(c);
        }
        abstractStr = parts.join(' ');
      } else {
        abstractStr = getStr(t, 'first_post_content', 'firstPostContent', '_abstract', 'abstract', 'abstractText', 'content', 'excerpt');
      }
      return !blockRepo.isThreadBlocked(forumName, uid, getStr(t, 'title', 'threadTitle', 'thread_title'), abstractStr);
    });
  }

  private extractForums(data: Dict): Dict[] {
    if (!data) return [];
    const d = (data.data as Dict) || data;
    const candidates = ['forum_list', 'like_forum', 'list', 'forum', 'forums', 'data_list', 'follow_list', 'follow_forum', 'like_list'];
    for (const key of candidates) {
      if (d[key] && Array.isArray(d[key]) && (d[key] as Dict[]).length > 0) {
        console.info('TiebaLite: extractForums matched key=' + key + ' count=' + (d[key] as Dict[]).length);
        return d[key] as Dict[];
      }
    }
    if (Array.isArray(data)) return data as Object as Dict[];
    if (Array.isArray(d)) return d as Object as Dict[];
    console.info('TiebaLite: extractForums no match, topKeys=' + Object.keys(data).join(',') + ' dataKeys=' + Object.keys(d).join(','));
    return [];
  }

  private getUnpinnedForums(): Dict[] {
    const pinnedIds = this.getPinnedForumIds();
    const result: Dict[] = [];
    for (const f of this.followedForums) {
      if (pinnedIds.indexOf(getStr(f, 'id', 'forum_id', 'forumId')) < 0) {
        result.push(f);
      }
    }
    return result;
  }

  private getPinnedForums(): Dict[] {
    const pinnedIds = this.getPinnedForumIds();
    const result: Dict[] = [];
    for (const f of this.followedForums) {
      if (pinnedIds.indexOf(getStr(f, 'id', 'forum_id', 'forumId')) >= 0) {
        result.push(f);
      }
    }
    result.sort((a, b) => {
      const ai = pinnedIds.indexOf(getStr(a, 'id', 'forum_id', 'forumId'));
      const bi = pinnedIds.indexOf(getStr(b, 'id', 'forum_id', 'forumId'));
      return ai - bi;
    });
    return result;
  }

  private getPinnedForumIds(): string[] {
    try {
      return this.pinnedForumIds ? JSON.parse(this.pinnedForumIds) as string[] : [];
    } catch (_e) { return []; }
  }

  private savePinnedForumIds(ids: string[]): void {
    this.pinnedForumIds = JSON.stringify(ids);
  }

  private isForumPinned(forum: Dict): boolean {
    return this.getPinnedForumIds().indexOf(getStr(forum, 'id', 'forum_id', 'forumId')) >= 0;
  }

  private pinForum(forum: Dict): void {
    const ids = this.getPinnedForumIds();
    const id = getStr(forum, 'id', 'forum_id', 'forumId');
    if (ids.indexOf(id) < 0) {
      ids.unshift(id);
      this.savePinnedForumIds(ids);
      this.followedForums = [...this.followedForums];
    }
  }

  private unpinForum(forum: Dict): void {
    const ids = this.getPinnedForumIds();
    const id = getStr(forum, 'id', 'forum_id', 'forumId');
    const idx = ids.indexOf(id);
    if (idx >= 0) {
      ids.splice(idx, 1);
      this.savePinnedForumIds(ids);
      this.followedForums = [...this.followedForums];
    }
  }

  private copyForumName(forum: Dict): void {
    const name = getStr(forum, 'name', 'forumName', 'forum_name');
    if (name) {
      try {
        let pbData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, name);
        let pb = pasteboard.getSystemPasteboard();
        void pb.setData(pbData);
      } catch (_e) {}
    }
  }

  private unfollowForum(forum: Dict): void {
    const id = getStr(forum, 'id', 'forum_id', 'forumId');
    const name = getStr(forum, 'name', 'forumName', 'forum_name');
    if (id) {
      void ForumRepository.getInstance().unlikeForum(Number(id), name).then(() => {
        this.followedForums = this.followedForums.filter(f =>
          getStr(f, 'id', 'forum_id', 'forumId') !== id
        );
      }).catch((e: Error) => {
        console.error('TiebaLite: unfollowForum error=' + String(e));
      });
    }
  }

  private isCurrentAccount(account: Account): boolean {
    const cur = AccountManager.getInstance().getCurrentAccountSync();
    return cur !== null && cur.uid === account.uid;
  }

  private getRecentForums(): Dict[] {
    try {
      if (this.recentForumsJson) return JSON.parse(this.recentForumsJson) as Dict[];
    } catch (_e) {}
    return [];
  }

  private getLevelColor(level: number): string {
    if (level <= 0) return '#999999';
    if (level <= 3) return '#999999';
    if (level <= 6) return '#4CAF50';
    if (level <= 9) return '#4477E0';
    if (level <= 12) return '#9C27B0';
    if (level <= 15) return '#FF6B35';
    return '#E53935';
  }

  private removeRecentForum(forum: Dict): void {
    const id = getStr(forum, 'id', 'forum_id', 'forumId');
    const name = getStr(forum, 'name', 'forumName', 'forum_name');
    let list: Dict[] = this.getRecentForums();
    list = list.filter((f: Dict) => {
      return getStr(f, 'id', 'forum_id', 'forumId') !== id && getStr(f, 'name', 'forumName', 'forum_name') !== name;
    });
    const json = JSON.stringify(list);
    AppStorage.Set<string>('recentForumsJson', json);
    this.recentForumsJson = json;
    try {
      PreferencesManager.getInstance().putString('recent_forums_json', json);
    } catch (_e) {}
  }

  private saveRecentForum(forum: Dict): void {
    if (!forum) return;
    const name = getStr(forum, 'name', 'forumName', 'forum_name');
    const id = getStr(forum, 'id', 'forum_id', 'forumId');
    if (!name) return;
    let list: Dict[] = [];
    try {
      const raw = AppStorage.Get<string>('recentForumsJson') || '';
      if (raw) list = JSON.parse(raw) as Dict[];
    } catch (_e) { list = []; }
    console.info('TiebaLite: saveRecentForum BEFORE name=' + name + ' id=' + id + ' listLen=' + list.length + ' list=' + JSON.stringify(list.map((f: Dict) => getStr(f, 'name'))));
    // Dedup by id or name
    list = list.filter((f: Dict) => {
      const fid = getStr(f, 'id', 'forum_id', 'forumId');
      const fname = getStr(f, 'name', 'forumName', 'forum_name');
      return fid !== id && fname !== name;
    });
    const entry: Dict = { name: name, id: id };
    const avatar = getStr(forum, 'avatar', 'forumAvatar');
    if (avatar) entry.avatar = avatar;
    list.unshift(entry);
    if (list.length > 30) list = list.slice(0, 30);
    const json = JSON.stringify(list);
    AppStorage.Set<string>('recentForumsJson', json);
    console.info('TiebaLite: saveRecentForum AFTER listLen=' + list.length + ' json=' + json);
    try {
      PreferencesManager.getInstance().putString('recent_forums_json', json);
    } catch (_e) {}
  }
}

