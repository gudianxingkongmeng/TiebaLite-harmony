import router from '@ohos.router';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import { blendWithBg, textAccent, pageBg, cardBg, cardRadius, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../../core/utils/DataHelper';
import AccountManager, { Account } from '../../core/auth/AccountManager';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';

@Entry
@Component
struct AccountManagePage {
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @State accounts: Account[] = [];
  @State currentAccount: Account | null = null;

  private accountManager: AccountManager = AccountManager.getInstance();

  async aboutToAppear(): Promise<void> {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
    this.accounts = this.accountManager.getAllAccounts();
    this.currentAccount = await this.accountManager.getCurrentAccount();
  }
  onIsDarkChange(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
  }

  onPageShow(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
  }

  build() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor(pageBg(this.isDark))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      Column() {
        Row() {
          Image($r('app.media.ic_arrow_back')).width(22).height(22).fillColor(textPrimary(this.isDark))
          Text('账号管理').fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark)).margin({ left: 16 })
          Blank()
        }
      .padding(12).width('100%').backgroundColor(pageBg(this.isDark))

      Scroll() {
        Column() {
          Text('当前账号').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).width('100%').padding(16)

          Column() {
            ForEach(this.accounts, (account: Account, idx: number) => {
              Row() {
                Circle().width(40).height(40).fill('#E0E0E0')
                Text((account.nickname || account.name).charAt(0))
                  .fontFamily(this.appFontFamily).fontSize(18).fontColor(textAccent(this.primaryColor, this.isDark))
                Column() {
                  Text(account.nickname || account.name).fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
                  Text('UID: ' + account.uid).fontFamily(this.appFontFamily).fontSize(12).fontColor(textTertiary(this.isDark)).margin({ top: 2 })
                }
                .margin({ left: 12 })
                .alignItems(HorizontalAlign.Start)
                Blank()
                if (this.currentAccount && this.currentAccount.uid === account.uid) {
                  Image($r('app.media.ic_check')).width(20).height(20).fillColor(this.primaryColor)
                }
              }
              .width('100%').height(60).padding({ left: 16, right: 16 })
              .onClick(async () => {
                if (this.currentAccount && this.currentAccount.uid !== account.uid) {
                  await this.accountManager.setCurrentAccount(account);
                  AppStorage.Set<boolean>('homeInitialLoadDone', false);
                  AppStorage.Set<boolean>('exploreInitialLoadDone', false);
                  AppStorage.Set<boolean>('notifInitialLoadDone', false);
                  AppStorage.Set<boolean>('storeInitialLoadDone', false);
                  this.currentAccount = account;
                }
              })
              if (idx < this.accounts.length - 1) {
                Divider().height(1.5).color(dividerColor(this.isDark)).margin({ left: 68 })
              }
            })
          }
          .width('100%').backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(8))

          Row() {
            Image($r('app.media.ic_add')).width(18).height(18).fillColor(this.primaryColor)
            Text('添加账号').fontFamily(this.appFontFamily).fontSize(16).fontColor(textAccent(this.primaryColor, this.isDark)).margin({ left: 4 })
          }
          .width('100%').height(48).justifyContent(FlexAlign.Center)
          .backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(8)).margin({ top: 16 })
          .onClick(() => {
            NavigationHelper.navigate('pages/login/LoginPage');
          })

          if (this.accounts.length > 0) {
            Row() {
              Text('退出当前账号').fontFamily(this.appFontFamily).fontSize(16).fontColor('#FF4444')
            }
            .width('100%').height(48).justifyContent(FlexAlign.Center)
            .backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(8)).margin({ top: 16 })
            .onClick(() => {
              AlertDialog.show({
                title: '退出登录',
                message: '确定要退出登录吗？',
                primaryButton: {
                  value: '取消',
                  action: () => {}
                },
                secondaryButton: {
                  value: '退出',
                  action: async () => {
                    await this.accountManager.logout();
                    this.accounts = this.accountManager.getAllAccounts();
                    this.currentAccount = await this.accountManager.getCurrentAccount();
                  }
                },
                cancel: () => {}
              });
            })

            Row() {
              Text('删除当前账号').fontFamily(this.appFontFamily).fontSize(16).fontColor('#FF4444')
            }
            .width('100%').height(48).justifyContent(FlexAlign.Center)
            .backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(8)).margin({ top: 12 })
            .onClick(() => {
              AlertDialog.show({
                title: '删除账号',
                message: '确定要删除此账号吗？此操作不可撤销。',
                primaryButton: {
                  value: '取消',
                  action: () => {}
                },
                secondaryButton: {
                  value: '删除',
                  action: async () => {
                    if (this.currentAccount) {
                      await this.accountManager.removeAccount(this.currentAccount.uid);
                      this.accounts = this.accountManager.getAllAccounts();
                      this.currentAccount = await this.accountManager.getCurrentAccount();
                    }
                  }
                },
                cancel: () => {}
              });
            })
          }
        }
        .width('100%').padding({ bottom: 32 }).backgroundColor(pageBg(this.isDark))
      }
        .scrollBar(BarState.Off)
      .width('100%').layoutWeight(1)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
    }
    .width('100%').height('100%').backgroundColor(pageBg(this.isDark))
  }

  onBackPress(): boolean {
    NavigationHelper.markBack();
    return false;
  }

  pageTransition() {
    if (NavigationHelper.isFadeTransition()) {
      if (NavigationHelper.isBack) {
        PageTransitionEnter({ duration: 300, curve: Curve.FastOutSlowIn })
          .opacity(0)
        PageTransitionExit({ duration: 300, curve: Curve.FastOutSlowIn })
          .opacity(0)
          .scale({ x: 0.94, y: 0.94 })
      } else {
        PageTransitionEnter({ duration: 300, curve: Curve.FastOutSlowIn })
          .opacity(0)
          .scale({ x: 0.96, y: 0.96 })
        PageTransitionExit({ duration: 300, curve: Curve.FastOutSlowIn })
          .opacity(0)
          .scale({ x: 1.04, y: 1.04 })
      }
    } else if (NavigationHelper.isBack) {
      PageTransitionEnter({ duration: 350, curve: Curve.FastOutSlowIn })
        .slide(SlideEffect.Left)
      PageTransitionExit({ duration: 300, curve: Curve.FastOutSlowIn })
        .slide(SlideEffect.Right)
    } else {
      PageTransitionEnter({ duration: 350, curve: Curve.FastOutSlowIn })
        .slide(SlideEffect.Right)
      PageTransitionExit({ duration: 300, curve: Curve.FastOutSlowIn })
        .slide(SlideEffect.Left)
    }
  }
}
