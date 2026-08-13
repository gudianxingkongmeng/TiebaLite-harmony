import router from '@ohos.router';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import PreferencesManager from '../../core/storage/PreferencesManager';
import ThemeProvider from '../../core/theme/ThemeProvider';
import { blendWithWhite, darkenColor, blendWithBg, textAccent, pageBg, cardBg, cardRadius, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../../core/utils/DataHelper';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';

@Entry
@Component
struct FontSettingsPage {
  @State fontScale: number = 1.0;
  @State useSystemFont: boolean = true;
  @State selectedFontIndex: number = 0;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';

  private prefs: PreferencesManager = PreferencesManager.getInstance();
  private fontOptions: string[] = ['系统', '默认', '衬线', '无衬线', '等宽', '手写'];

  async aboutToAppear(): Promise<void> {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
    this.fontScale = await this.prefs.getFloat('fontScale', 1.0);
    this.useSystemFont = await this.prefs.getBoolean('use_system_font', true);
    this.selectedFontIndex = await this.prefs.getInt('custom_font', 0);
    this.appFontFamily = AppStorage.Get<string>('appFontFamily') || '';
  }
  onIsDarkChange(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
  }

  onPageShow(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
  }

  private getFontSizeName(): string {
    if (this.fontScale <= 0.9) return '小';
    if (this.fontScale <= 1.1) return '标准';
    if (this.fontScale <= 1.3) return '大';
    return '超大';
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
          Text('字体设置').fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark)).margin({ left: 16 })
          Blank()
        }
      .padding(12).width('100%').backgroundColor(pageBg(this.isDark))

      Scroll() {
        Column() {
          Text('字体大小').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).width('100%').padding(16)

          Column() {
            Row() {
              Text('大小').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Text(this.getFontSizeName()).fontFamily(this.appFontFamily).fontSize(16).fontColor(textAccent(this.primaryColor, this.isDark))
            }
            .width('100%').height(32).padding({ left: 16, right: 16 })

            Slider({ value: this.fontScale, min: 0.8, max: 1.6, step: 0.1 })
              .width('100%').padding({ left: 16, right: 16 })
              .onChange(async (value: number) => {
                this.fontScale = Number(value.toFixed(1));
                await ThemeProvider.getInstance().setFontScale(this.fontScale);
              })

            Text('当前：' + this.fontScale.toFixed(1) + 'x')
              .fontFamily(this.appFontFamily).fontSize(12).fontColor(textTertiary(this.isDark)).width('100%').padding({ left: 16, right: 16, top: 4 })
          }
          .width('100%').backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(8)).padding({ bottom: 12 })

          Text('预览').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).width('100%').padding(16)

          Column() {
            Text('汉字预览效果示例。TiebaLite~')
              .fontFamily(this.appFontFamily).fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontColor(textPrimary(this.isDark)).width('100%').padding(16)
            Divider().height(1).color(dividerColor(this.isDark)).margin({ left: 16 })
            Text('汉字预览效果示例。')
              .fontFamily(this.appFontFamily).fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textSecondary(this.isDark)).width('100%').padding(16)
          }
          .width('100%').backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(8))

          Text('系统字体').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).width('100%').padding(16)

          Column() {
            Row() {
              Text('使用系统字体').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.useSystemFont })
                .onChange(async (v) => {
                  this.useSystemFont = v;
                  await this.prefs.putBoolean('use_system_font', v);
                  await ThemeProvider.getInstance().setFontFamily(v, this.selectedFontIndex);
                  this.appFontFamily = AppStorage.Get<string>('appFontFamily') || '';
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })

            if (!this.useSystemFont) {
              Divider().height(1).color(dividerColor(this.isDark)).margin({ left: 16 })
              ForEach(this.fontOptions, (font: string, idx: number) => {
                Row() {
                  Text(font).fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
                  Blank()
                  if (idx === this.selectedFontIndex) {
                    Image($r('app.media.ic_check')).width(22).height(22).fillColor(this.primaryColor)
                  }
                }
                .width('100%').height(48).padding({ left: 16, right: 16 })
                .onClick(async () => {
                  this.selectedFontIndex = idx;
                  await this.prefs.putInt('custom_font', idx);
                  await ThemeProvider.getInstance().setFontFamily(this.useSystemFont, idx);
                  this.appFontFamily = AppStorage.Get<string>('appFontFamily') || '';
                })
                if (idx < this.fontOptions.length - 1) {
                  Divider().height(1).color(dividerColor(this.isDark)).margin({ left: 16 })
                }
              })
            }
          }
          .width('100%').backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(8))
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
