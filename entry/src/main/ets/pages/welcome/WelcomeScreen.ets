import router from '@ohos.router';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';
import { blendWithBg, pageBg, cardBg, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../../core/utils/DataHelper';
import PreferencesManager from '../../core/storage/PreferencesManager';

@Entry
@Component
struct WelcomeScreen {
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @State step: number = 0;
  private pages = ['欢迎使用贴吧Lite', '无广告', '快速流畅', '开始使用'];

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
        Column() {
          Text(this.pages[this.step]).fontFamily(this.appFontFamily).fontSize(28).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark))
          .textAlign(TextAlign.Center).margin({ top: 80 })

        if (this.step === 0) {
          Text('一个纯净的第三方百度贴吧客户端').fontFamily(this.appFontFamily).fontSize(16).fontColor(textSecondary(this.isDark)).margin({ top: 16 })
        } else if (this.step === 1) {
          Text('无广告，更清爽的浏览体验').fontFamily(this.appFontFamily).fontSize(16).fontColor(textSecondary(this.isDark)).margin({ top: 16 })
        } else if (this.step === 2) {
          Text('快速流畅，资源占用少').fontFamily(this.appFontFamily).fontSize(16).fontColor(textSecondary(this.isDark)).margin({ top: 16 })
        } else {
          Blank()
        }
        }
        .width('100%').layoutWeight(1)

        Row() {
          ForEach(this.pages, (_page: string, idx: number) => {
            Column()
              .width(this.step === idx ? 24 : 8).height(8)
              .backgroundColor(this.step === idx ? this.primaryColor : dividerColor(this.isDark))
              .borderRadius(4).margin({ left: 4, right: 4 })
          })
        }
        .width('100%').justifyContent(FlexAlign.Center).padding({ bottom: 40 })

        if (this.step < 3) {
          Button('跳过').fontFamily(this.appFontFamily).fontSize(16).fontColor(textSecondary(this.isDark)).backgroundColor('transparent').onClick(() => { this.step = 3; })
        }
        Button(this.step < 3 ? '下一步' : '开始使用').fontFamily(this.appFontFamily).fontSize(16).fontColor('#FFFFFF').backgroundColor(this.primaryColor).borderRadius(22).width(200).height(44)
          .onClick(() => {
            if (this.step < 3) {
              this.step++;
            } else {
              PreferencesManager.getInstance().putBoolean('welcome_done', true);
              router.replaceUrl({ url: 'pages/Index' });
            }
          })
      }
      .width('100%').height('100%').backgroundColor(pageBg(this.isDark)).expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    
  }
}
