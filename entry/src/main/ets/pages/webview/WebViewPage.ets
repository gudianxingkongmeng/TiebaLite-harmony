import router from '@ohos.router';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import { blendWithBg, pageBg, cardBg, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../../core/utils/DataHelper';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';
import webview from '@ohos.web.webview';

@Entry
@Component
struct WebViewPage {
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();
  @State url: string = '';
  @State title: string = '';
  @State loading: boolean = true;
  @State progress: number = 0;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.url = params?.url || 'https://tieba.baidu.com';
    this.title = params?.title || '';
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
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      Column() {
        Row() {
          Image($r('app.media.ic_arrow_back')).width(22).height(22).fillColor(textPrimary(this.isDark)).onClick(() => router.back())
          Text(this.title || '浏览帖子').fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold)
          .margin({ left: 12 }).layoutWeight(1)
        if (this.loading) {
          LoadingProgress().width(20).height(20)
        }
      }
      .padding(12).width('100%').backgroundColor(cardBg(this.isDark))

      if (this.progress > 0 && this.progress < 100) {
        Row() {
          Row().width(`${this.progress}%`).height(3).backgroundColor('#4477E0')
        }
        .width('100%').height(3).backgroundColor(dividerColor(this.isDark))
      }

      Web({ src: this.url, controller: this.controller })
        .width('100%').layoutWeight(1)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .onControllerAttached(() => {
          console.info('TiebaLite: WebView controller attached, url=' + this.url);
        })
        .onPageBegin((event) => {
          this.loading = true;
          console.info('TiebaLite: WebView page begin url=' + (event ? event.url : this.url));
        })
        .onPageEnd((event) => {
          this.loading = false;
          console.info('TiebaLite: WebView page end url=' + (event ? event.url : this.url));
        })
        .onErrorReceive((event) => {
          let errUrl: string = this.url;
          try { errUrl = String(event?.request?.getRequestUrl()); } catch (e) {}
          console.error('TiebaLite: WebView onErrorReceive url=' + errUrl);
        })
        .onHttpErrorReceive((event) => {
          let errUrl: string = this.url;
          try { errUrl = String(event?.request?.getRequestUrl()); } catch (e) {}
          let code: string = '?';
          try { code = String(event?.response?.getResponseCode()); } catch (e) {}
          console.error('TiebaLite: WebView onHttpErrorReceive url=' + errUrl + ' code=' + code);
        })
        .onProgressChange((p) => { this.progress = (p as Object as Record<string, number>).progress || 0; })
    }
    .width('100%').height('100%').backgroundColor(pageBg(this.isDark)).expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .width('100%').height('100%').backgroundColor(pageBg(this.isDark)).expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    
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

