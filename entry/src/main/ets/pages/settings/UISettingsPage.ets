import router from '@ohos.router';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import { blendWithBg, textAccent, pageBg, cardBg, cardRadius, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../../core/utils/DataHelper';
import PreferencesManager from '../../core/storage/PreferencesManager';
import ThemeProvider from '../../core/theme/ThemeProvider';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';

@Entry
@Component
struct UISettingsPage {
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @State navStyle: number = 0;
  @State showNavLabels: boolean = true;
  @State showSwiperDots: boolean = true;
  @State cardStyle: number = 0;
  @State showThreadPreview: boolean = true;
  @State showRecentForums: boolean = true;
  @State refreshStyle: number = 0;
  @State hideOnScroll: boolean = true;
  @State pageTransitionStyle: number = 0;
  @State headerAlpha: number = 25;
  @State headerTint: number = 8;
  @State searchBoxRound: number = 100;

  private prefs: PreferencesManager = PreferencesManager.getInstance();
  private themeProvider: ThemeProvider = ThemeProvider.getInstance();
  private navStyles: string[] = ['悬浮导航'];
  private cardStyles: string[] = ['卡片显示', '分隔显示'];
  private pageTransitions: string[] = ['左右切换', '淡入淡出'];
  private refreshStyles: string[] = ['齿轮', '圆环'];

  async aboutToAppear(): Promise<void> {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
    this.navStyle = Math.max(0, Math.min(await this.prefs.getInt('nav_style', 0), this.navStyles.length - 1));
    this.showNavLabels = await this.prefs.getBoolean('show_nav_labels', true);
    this.showSwiperDots = await this.prefs.getBoolean('show_swiper_dots', true);
    this.cardStyle = await this.prefs.getInt('card_style', 0);
    this.showThreadPreview = await this.prefs.getBoolean('show_thread_preview', true);
    this.showRecentForums = await this.prefs.getBoolean('show_recent_forums', true);
    let refreshStyle = await this.prefs.getInt('ui_refresh_style', -1);
    if (refreshStyle < 0) {
      refreshStyle = (await this.prefs.getBoolean('ui_reduce_effect', false)) ? 1 : 0;
    }
    this.refreshStyle = Math.max(0, Math.min(refreshStyle, this.refreshStyles.length - 1));
    this.hideOnScroll = await this.prefs.getBoolean('ui_hide_on_scroll', true);
    this.pageTransitionStyle = Math.max(0, Math.min(await this.prefs.getInt('page_transition_style', 0), this.pageTransitions.length - 1));
    this.headerAlpha = Math.max(0, Math.min(await this.prefs.getInt('header_alpha', 25), 100));
    this.headerTint = Math.max(0, Math.min(await this.prefs.getInt('header_tint', 8), 100));
    this.searchBoxRound = Math.max(0, Math.min(await this.prefs.getInt('search_box_round', 100), 100));
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
          Text('界面设置').fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark)).margin({ left: 16 })
          Blank()
        }
      .padding(12).width('100%').backgroundColor(pageBg(this.isDark))

      Scroll() {
        Column() {
          Text('导航').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).width('100%').padding(16)

          Column() {
            Row() {
              Text('导航样式').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Select(this.navStyles.map((s: string): SelectOption => ({ value: s })))
                .selected(this.navStyle)
                .value(this.navStyles[this.navStyle])
                .fontColor(textAccent(this.primaryColor, this.isDark))
                .onSelect(async (idx: number) => {
                  this.navStyle = idx;
                  await this.prefs.putInt('nav_style', idx);
                  AppStorage.SetOrCreate('navStyle', idx);
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })

            Divider().height(1.5).color(dividerColor(this.isDark)).margin({ left: 16 })

            Row() {
              Text('显示导航标签').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.showNavLabels })
                .onChange(async (v) => {
                  this.showNavLabels = v;
                  await this.prefs.putBoolean('show_nav_labels', v);
                  AppStorage.SetOrCreate('showNavLabels', v);
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })

            Divider().height(1.5).color(dividerColor(this.isDark)).margin({ left: 16 })

            Row() {
              Text('显示分栏圆点').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.showSwiperDots })
                .onChange(async (v) => {
                  this.showSwiperDots = v;
                  await this.prefs.putBoolean('show_swiper_dots', v);
                  AppStorage.SetOrCreate('showSwiperDots', v);
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })
          }
          .width('100%').backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(8))

          Text('卡片').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).width('100%').padding(16)

          Column() {
            Row() {
              Text('卡片样式').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Select(this.cardStyles.map((s: string): SelectOption => ({ value: s })))
                .selected(this.cardStyle)
                .value(this.cardStyles[this.cardStyle])
                .fontColor(textAccent(this.primaryColor, this.isDark))
                .onSelect(async (idx: number) => {
                  this.cardStyle = idx;
                  await this.prefs.putInt('card_style', idx);
                  AppStorage.SetOrCreate('cardStyle', idx);
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })

            Divider().height(1.5).color(dividerColor(this.isDark)).margin({ left: 16 })

            Row() {
              Text('显示帖子预览').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.showThreadPreview })
                .onChange(async (v) => {
                  this.showThreadPreview = v;
                  await this.prefs.putBoolean('show_thread_preview', v);
                  AppStorage.SetOrCreate('showThreadPreview', v);
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })

            Divider().height(1.5).color(dividerColor(this.isDark)).margin({ left: 16 })

            Row() {
              Text('显示最近访问').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.showRecentForums })
                .onChange(async (v) => {
                  this.showRecentForums = v;
                  await this.prefs.putBoolean('show_recent_forums', v);
                  AppStorage.SetOrCreate('showRecentForums', v);
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })
          }
          .width('100%').backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(8))

          Text('效果').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).width('100%').padding(16)

          Column() {
            Row() {
              Text('刷新样式').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Select(this.refreshStyles.map((s: string): SelectOption => ({ value: s })))
                .selected(this.refreshStyle)
                .value(this.refreshStyles[this.refreshStyle])
                .fontColor(textAccent(this.primaryColor, this.isDark))
                .onSelect(async (idx: number) => {
                  this.refreshStyle = idx;
                  void this.themeProvider.setRefreshStyle(idx);
                  await this.prefs.putInt('ui_refresh_style', idx);
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })

            Divider().height(1.5).color(dividerColor(this.isDark)).margin({ left: 16 })

            Row() {
              Text('界面切换').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Select(this.pageTransitions.map((s: string): SelectOption => ({ value: s })))
                .selected(this.pageTransitionStyle)
                .value(this.pageTransitions[this.pageTransitionStyle])
                .fontColor(textAccent(this.primaryColor, this.isDark))
                .onSelect(async (idx: number) => {
                  this.pageTransitionStyle = idx;
                  await this.prefs.putInt('page_transition_style', idx);
                  AppStorage.SetOrCreate('pageTransitionStyle', idx);
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })

            Divider().height(1.5).color(dividerColor(this.isDark)).margin({ left: 16 })

            Row() {
              Text('滚动时收起顶部栏').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.hideOnScroll })
                .onChange(async (v) => {
                  this.hideOnScroll = v;
                  await this.prefs.putBoolean('ui_hide_on_scroll', v);
                  AppStorage.SetOrCreate('hideOnScroll', v);
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })

            Divider().height(1.5).color(dividerColor(this.isDark)).margin({ left: 16 })

            Row() {
              Text('顶栏透明度').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Text(this.headerAlpha + '%')
                .fontFamily(this.appFontFamily).fontSize(13).fontColor(textTertiary(this.isDark)).margin({ right: 8 })
              Slider({ value: this.headerAlpha, min: 0, max: 100, step: 1 })
                .width(140)
                .showSteps(true)
                .onChange((value: number, mode: SliderChangeMode) => {
                  this.headerAlpha = Math.round(value);
                  if (mode === SliderChangeMode.End) {
                    const v = Math.max(0, Math.min(Math.round(value), 100));
                    void this.prefs.putInt('header_alpha', v);
                    AppStorage.SetOrCreate('headerAlpha', v);
                  }
                })
            }
            .width('100%').height(56).padding({ left: 16, right: 16 })

            Divider().height(1.5).color(dividerColor(this.isDark)).margin({ left: 16 })

            Row() {
              Text('顶栏背景加深').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Text(this.headerTint + '%')
                .fontFamily(this.appFontFamily).fontSize(13).fontColor(textTertiary(this.isDark)).margin({ right: 8 })
              Slider({ value: this.headerTint, min: 0, max: 100, step: 1 })
                .width(140)
                .showSteps(true)
                .onChange((value: number, mode: SliderChangeMode) => {
                  this.headerTint = Math.round(value);
                  if (mode === SliderChangeMode.End) {
                    const v = Math.max(0, Math.min(Math.round(value), 100));
                    void this.prefs.putInt('header_tint', v);
                    AppStorage.SetOrCreate('headerTint', v);
                  }
                })
            }
            .width('100%').height(56).padding({ left: 16, right: 16 })

            Divider().height(1.5).color(dividerColor(this.isDark)).margin({ left: 16 })

            Row() {
              Text('搜索框圆角').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Text(this.searchBoxRound + '%')
                .fontFamily(this.appFontFamily).fontSize(13).fontColor(textTertiary(this.isDark)).margin({ right: 8 })
              Slider({ value: this.searchBoxRound, min: 0, max: 100, step: 1 })
                .width(140)
                .showSteps(true)
                .onChange((value: number, mode: SliderChangeMode) => {
                  this.searchBoxRound = Math.round(value);
                  if (mode === SliderChangeMode.End) {
                    const v = Math.max(0, Math.min(Math.round(value), 100));
                    void this.prefs.putInt('search_box_round', v);
                    AppStorage.SetOrCreate('searchBoxRound', v);
                  }
                })
            }
            .width('100%').height(56).padding({ left: 16, right: 16 })
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
