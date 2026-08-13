import router from '@ohos.router';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import PreferencesManager from '../../core/storage/PreferencesManager';
import { blendWithWhite, darkenColor, blendWithBg, textAccent, pageBg, cardBg, cardRadius, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../../core/utils/DataHelper';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';

@Entry
@Component
struct SignInSettingsPage {
  @State autoSign: boolean = false;
  @State signNotify: boolean = false;
  @State signTime: number = 8;
  @State signWifiOnly: boolean = false;
  @State signBadge: boolean = false;
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  @StorageLink('appFontFamily') appFontFamily: string = '';

  private hours: string[] = [];
  private prefs: PreferencesManager = PreferencesManager.getInstance();

  async aboutToAppear(): Promise<void> {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
    for (let i = 0; i < 24; i++) {
      this.hours.push(i.toString().padStart(2, '0') + ':00');
    }
    this.autoSign = await this.prefs.getBoolean('auto_sign', false);
    this.signNotify = await this.prefs.getBoolean('sign_notify', false);
    this.signTime = await this.prefs.getInt('sign_time', 8);
    this.signWifiOnly = await this.prefs.getBoolean('sign_wifi_only', false);
    this.signBadge = await this.prefs.getBoolean('sign_badge', false);
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
          Text('签到设置').fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark)).margin({ left: 16 })
          Blank()
        }
      .padding(12).width('100%').backgroundColor(pageBg(this.isDark))

      Scroll() {
        Column() {
          Text('签到选项').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).width('100%').padding(16)

          Column() {
            Row() {
              Text('自动签到').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.autoSign })
                .onChange(async (v) => {
                  this.autoSign = v;
                  await this.prefs.putBoolean('auto_sign', v);
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })

            Divider().height(1).color(dividerColor(this.isDark)).margin({ left: 16 })

            Row() {
              Text('签到通知').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.signNotify })
                .onChange(async (v) => {
                  this.signNotify = v;
                  await this.prefs.putBoolean('sign_notify', v);
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })

            Divider().height(1).color(dividerColor(this.isDark)).margin({ left: 16 })

            Row() {
              Text('签到时间').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Select(this.hours.map((h: string): SelectOption => ({ value: h })))
                .selected(this.signTime)
                .value(this.hours[this.signTime])
                .fontColor(textAccent(this.primaryColor, this.isDark))
                .onSelect(async (idx: number) => {
                  this.signTime = idx;
                  await this.prefs.putInt('sign_time', idx);
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })

            Divider().height(1).color(dividerColor(this.isDark)).margin({ left: 16 })

            Row() {
              Text('仅WiFi').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.signWifiOnly })
                .onChange(async (v) => {
                  this.signWifiOnly = v;
                  await this.prefs.putBoolean('sign_wifi_only', v);
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })

            Divider().height(1).color(dividerColor(this.isDark)).margin({ left: 16 })

            Row() {
              Text('显示角标').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.signBadge })
                .onChange(async (v) => {
                  this.signBadge = v;
                  await this.prefs.putBoolean('sign_badge', v);
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })
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
