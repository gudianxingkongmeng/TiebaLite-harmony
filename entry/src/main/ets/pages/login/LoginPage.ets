import router from '@ohos.router';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import webview from '@ohos.web.webview';
import AccountManager from '../../core/auth/AccountManager';
import { blendWithWhite, darkenColor, blendWithBg, pageBg, cardBg, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../../core/utils/DataHelper';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';

@Entry
@Component
struct LoginPage {
  private controller: webview.WebviewController = new webview.WebviewController();
  @State loading: boolean = true;
  @State loginSuccess: boolean = false;
  @State loginError: string = '';
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  @StorageLink('appFontFamily') appFontFamily: string = '';
  private loginAttempted: boolean = false;
  private url: string = 'https://wappass.baidu.com/passport?login&u=https%3A%2F%2Ftieba.baidu.com%2Findex%2Ftbwise%2Fmine';

  aboutToAppear(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
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
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
      Column() {
        Row() {
          Row() {
            Image($r('app.media.ic_arrow_back')).width(18).height(18).fillColor(textPrimary(this.isDark))
            Text('返回')
              .fontFamily(this.appFontFamily).fontSize(16).fontColor('#4477E0').margin({ left: 4 })
        }.onClick(() => { router.back(); })
        Blank()
        Text('登录百度账号')
          .fontFamily(this.appFontFamily).fontSize(18).fontWeight(FontWeight.Bold)
        Blank()
      }
      .padding(12)
      .width('100%')

      if (this.loginSuccess) {
        Column() {
          Text('登录成功!')
            .fontFamily(this.appFontFamily).fontSize(24).fontColor('#4CAF50')
            .margin({ top: 60 })
          Text('正在获取账号信息...')
            .fontFamily(this.appFontFamily).fontSize(16).fontColor(textSecondary(this.isDark))
            .margin({ top: 16 })
          LoadingProgress()
            .width(48).height(48)
            .color('#4477E0')
            .margin({ top: 32 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Center)
      } else {
        Column() {
          if (this.loginError) {
            Text(this.loginError)
              .fontFamily(this.appFontFamily).fontSize(14).fontColor('#FF4444').padding(8)
          }
          Web({ src: this.url, controller: this.controller })
            .width('100%')
            .layoutWeight(1)
            .multiWindowAccess(true)
            .domStorageAccess(true)
            .databaseAccess(true)
            .cacheMode(CacheMode.Online)
            .userAgent('Mozilla/5.0 (Linux; Android 14; HarmonyOS) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/99.0.4844.88 Mobile Safari/537.36')
            .onPageBegin((event) => {
              console.info('TiebaLite: [LOGIN] onPageBegin url=' + event.url);
              this.loading = true;
            })
            .onPageEnd((event) => {
              this.loading = false;
              console.info('TiebaLite: [LOGIN] onPageEnd url=' + event.url);
              this.checkTiebaRedirect(event.url);
            })
            .onErrorReceive((err) => {
              console.error('TiebaLite: [LOGIN] onErrorReceive url=' + this.controller.getUrl());
              this.loading = false;
            })
            .onAlert(() => {
              console.info('TiebaLite: [LOGIN] onAlert suppressed');
              return true;
            })
            .onConfirm(() => {
              console.info('TiebaLite: [LOGIN] onConfirm suppressed');
              return true;
            })
            .onPrompt(() => {
              console.info('TiebaLite: [LOGIN] onPrompt suppressed');
              return true;
            })
        }
        .width('100%')
        .height('100%')
      }
      if (!this.loginSuccess && this.loginError) {
        Row() {
          Button('重试')
            .fontFamily(this.appFontFamily).fontSize(14).fontColor('#FFFFFF')
            .backgroundColor('#4477E0')
            .borderRadius(18)
            .padding({ left: 24, right: 24 })
            .onClick(() => {
              this.loginError = '';
              this.loginAttempted = false;
              this.controller.refresh();
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding(8)
        .backgroundColor(cardBg(this.isDark))
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    }
    .width('100%').height('100%')
    .backgroundColor(pageBg(this.isDark)).expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    
  }

  private async checkTiebaRedirect(url: string): Promise<void> {
    if (this.loginSuccess || this.loginAttempted) return;

    console.info('TiebaLite: [LOGIN] checkTiebaRedirect url=' + url);

    if (!url.includes('tieba.baidu.com/index/tbwise') && !url.includes('tiebac.baidu.com/index/tbwise')) {
      console.info('TiebaLite: [LOGIN] not a tieba redirect, skipping');
      return;
    }

    console.info('TiebaLite: [LOGIN] detected tieba redirect! Extracting cookies...');
    this.loginAttempted = true;

    try {
      const cookies = await webview.WebCookieManager.getCookie(url);
      console.info('TiebaLite: [LOGIN] cookies from ' + url + ': ' + (cookies ? cookies.substring(0, 300) : 'null'));

      let allCookies: string = cookies || '';
      if (!allCookies.includes('BDUSS=')) {
        const domains = ['https://passport.baidu.com', 'https://www.baidu.com', 'https://baidu.com'];
        for (const d of domains) {
          const c = await webview.WebCookieManager.getCookie(d);
          console.info('TiebaLite: [LOGIN] cookies from ' + d + ': ' + (c ? c.substring(0, 200) : 'null'));
          if (c) allCookies += c;
        }
      }

      if (!allCookies.includes('BDUSS=')) {
        console.info('TiebaLite: [LOGIN] BDUSS not found in any domain, will retry');
        this.loginAttempted = false;
        setTimeout(() => this.checkTiebaRedirect(url), 2000);
        return;
      }

      const bduss = this.extractCookie(allCookies, 'BDUSS');
      const stoken = this.extractCookie(allCookies, 'STOKEN');
      console.info('TiebaLite: [LOGIN] BDUSS=' + (bduss ? bduss.substring(0, 20) + '...' : 'null'));
      console.info('TiebaLite: [LOGIN] STOKEN=' + (stoken ? stoken.substring(0, 20) + '...' : 'null'));

      if (!bduss) {
        console.error('TiebaLite: [LOGIN] BDUSS is empty after extraction');
        this.loginError = '获取BDUSS Cookie失败';
        this.loginAttempted = false;
        return;
      }

      this.loginSuccess = true;

      try {
        console.info('TiebaLite: [LOGIN] calling AccountManager.addAccount...');
        const account = await AccountManager.getInstance().addAccount(bduss, stoken || '');
        if (account) {
          console.info('TiebaLite: [LOGIN] addAccount success, uid=' + account.uid);
          setTimeout(() => {
            console.info('TiebaLite: [LOGIN] navigating back');
            router.back();
          }, 1500);
        } else {
          console.error('TiebaLite: [LOGIN] addAccount returned null');
          this.loginError = '获取账号信息失败';
          this.loginSuccess = false;
          this.loginAttempted = false;
        }
      } catch (e) {
        console.error('TiebaLite: [LOGIN] addAccount exception:', String(e));
        this.loginError = '保存账号失败: ' + String(e);
        this.loginSuccess = false;
        this.loginAttempted = false;
      }
    } catch (e) {
      console.error('TiebaLite: [LOGIN] checkTiebaRedirect exception:', String(e));
      this.loginError = '登录异常: ' + String(e);
      this.loginAttempted = false;
    }
  }

  private extractCookie(cookieStr: string, name: string): string {
    const regex = new RegExp(`${name}=([^;]+)`);
    const match = cookieStr.match(regex);
    return match ? match[1] : '';
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
