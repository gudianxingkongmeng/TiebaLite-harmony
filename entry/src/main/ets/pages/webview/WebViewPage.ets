import { TopInsetHelper } from '../../core/utils/TopInsetHelper';
import common from '@ohos.app.ability.common';
import router from '@ohos.router';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import { pageBg, textPrimary, dividerColor, glassTopBarSurface, glassTopBarEffect } from '../../core/utils/DataHelper';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';
import webview from '@ohos.web.webview';

@Entry
@Component
struct WebViewPage {
  @StorageLink('headerAlpha') headerAlpha: number = 25;
  @State topInset: number = 24;
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();
  @State url: string = '';
  @State title: string = '';
  @State loading: boolean = true;
  @State progress: number = 0;

  aboutToAppear(): void {
    void TopInsetHelper.get(getContext(this) as common.UIAbilityContext).then((v: number): void => { this.topInset = v; }).catch(() => {});
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
      .padding({ left: 12, right: 12, bottom: 12, top: 12 + this.topInset }).width('100%')
      .backgroundColor(glassTopBarSurface(pageBg(this.isDark), this.isDark, this.headerAlpha))
      .backdropBlur(this.headerAlpha > 0 ? 35 : 0)
        .backgroundEffect(glassTopBarEffect(this.headerAlpha))
      .border({ width: { bottom: 1 }, color: dividerColor(this.isDark) })

.position({ x: 0, y: 0 })

.zIndex(2)

      if (this.progress > 0 && this.progress < 100) {
        Row() {
          Row().width(`${this.progress}%`).height(3).backgroundColor('#4477E0')
        }
        .width('100%').height(3).backgroundColor(dividerColor(this.isDark))
      }

      Web({ src: this.url, controller: this.controller })
        .width('100%').layoutWeight(1)
        .margin({ top: 46 + this.topInset })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .onPageBegin(() => {
          this.loading = true;
        })
        .onPageEnd(() => {
          this.loading = false;
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

