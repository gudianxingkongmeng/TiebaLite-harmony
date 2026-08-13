import router from '@ohos.router';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import { blendWithBg, textAccent, pageBg, cardBg, cardRadius, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../../core/utils/DataHelper';
import PreferencesManager from '../../core/storage/PreferencesManager';
import NetworkUtil from '../../core/utils/NetworkUtil';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';

@Entry
@Component
struct HabitsSettingsPage {
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @State defaultTab: number = 0;
  @State forumSort: number = 0;
  @State imageLoadMode: number = 0;
  @State videoAutoplay: number = 0;
  @State videoDefaultMute: boolean = true;
  @State videoPreviewMute: boolean = true;
  @State videoListPip: boolean = false;
  @State pipEnabled: boolean = true;
  @State openLinksInApp: boolean = true;
  @StorageLink('gripEnabled') gripEnabled: boolean = true;
  @StorageLink('fabRadius') fabRadius: number = 60;
  private fabTimer: number = -1;

  private prefs: PreferencesManager = PreferencesManager.getInstance();
  private tabs: string[] = ['首页', '发现', '通知', '我的'];
  private sortOrders: string[] = ['按活动', '按名称'];
  private loadModes: string[] = ['自动', '仅WiFi', '手动'];
  private autoplayModes: string[] = ['自动', '仅WiFi', '手动'];

  async aboutToAppear(): Promise<void> {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
    this.defaultTab = await this.prefs.getInt('default_tab', 0);
    this.forumSort = await this.prefs.getInt('forum_sort', 0);
    this.imageLoadMode = await this.prefs.getInt('image_load_mode', 0);
    this.videoAutoplay = await this.prefs.getInt('video_autoplay', 0);
    this.videoDefaultMute = await this.prefs.getBoolean('video_default_mute', true);
    AppStorage.SetOrCreate<boolean>('videoDefaultMute', this.videoDefaultMute);
    this.videoPreviewMute = await this.prefs.getBoolean('video_preview_mute', true);
    AppStorage.SetOrCreate<boolean>('videoPreviewMute', this.videoPreviewMute);
    this.videoListPip = await this.prefs.getBoolean('video_list_pip', false);
    AppStorage.SetOrCreate<boolean>('videoListPip', this.videoListPip);
    this.pipEnabled = await this.prefs.getBoolean('pip_enabled', true);
    AppStorage.SetOrCreate<boolean>('pipEnabled', this.pipEnabled);
    this.openLinksInApp = await this.prefs.getBoolean('open_links_in_app', true);
    const gripEnabled = await this.prefs.getBoolean('grip_enabled', true);
    AppStorage.SetOrCreate<boolean>('gripEnabled', gripEnabled);
    const fabRadius = await this.prefs.getInt('fab_radius', 60);
    AppStorage.SetOrCreate<number>('fabRadius', fabRadius);
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
          Text('偏好设置').fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark)).margin({ left: 16 })
          Blank()
        }
      .padding(12).width('100%').backgroundColor(pageBg(this.isDark))

      Scroll() {
        Column() {
          Text('标签页').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).width('100%').padding(16)

          Column() {
            Row() {
              Text('默认标签页').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Select(this.tabs.map((t: string): SelectOption => ({ value: t })))
                .selected(this.defaultTab)
                .value(this.tabs[this.defaultTab])
                .fontColor(textAccent(this.primaryColor, this.isDark))
                .onSelect(async (idx: number) => {
                  this.defaultTab = idx;
                  await this.prefs.putInt('default_tab', idx);
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })
          }
          .width('100%').backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(8))

          Column() {
            Row() {
              Text('贴吧排序').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Select(this.sortOrders.map((s: string): SelectOption => ({ value: s })))
                .selected(this.forumSort)
                .value(this.sortOrders[this.forumSort])
                .fontColor(textAccent(this.primaryColor, this.isDark))
                .onSelect(async (idx: number) => {
                  this.forumSort = idx;
                  await this.prefs.putInt('forum_sort', idx);
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })
          }
          .width('100%').backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(8))

          Text('媒体').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).width('100%').padding(16)

          Column() {
            Row() {
              Text('图片加载模式').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Select(this.loadModes.map((m: string): SelectOption => ({ value: m })))
                .selected(this.imageLoadMode)
                .value(this.loadModes[this.imageLoadMode])
                .fontColor(textAccent(this.primaryColor, this.isDark))
                .onSelect(async (idx: number) => {
                  this.imageLoadMode = idx;
                  AppStorage.SetOrCreate<number>('imageLoadMode', idx);
                  await this.prefs.putInt('image_load_mode', idx);
                  void NetworkUtil.publishWifiState();
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })

            Divider().height(1).color(dividerColor(this.isDark)).margin({ left: 16 })

            Row() {
              Text('视频自动播放').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Select(this.autoplayModes.map((m: string): SelectOption => ({ value: m })))
                .selected(this.videoAutoplay)
                .value(this.autoplayModes[this.videoAutoplay])
                .fontColor(textAccent(this.primaryColor, this.isDark))
                .onSelect(async (idx: number) => {
                  this.videoAutoplay = idx;
                  await this.prefs.putInt('video_autoplay', idx);
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })

            Divider().height(1).color(dividerColor(this.isDark)).margin({ left: 16 })

            Row() {
              Text('视频播放静音').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.videoDefaultMute })
                .onChange(async (v) => {
                  this.videoDefaultMute = v;
                  AppStorage.SetOrCreate<boolean>('videoDefaultMute', v);
                  await this.prefs.putBoolean('video_default_mute', v);
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })

            Divider().height(1).color(dividerColor(this.isDark)).margin({ left: 16 })

            Row() {
              Text('视频预览静音').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.videoPreviewMute })
                .onChange(async (v) => {
                  this.videoPreviewMute = v;
                  AppStorage.SetOrCreate<boolean>('videoPreviewMute', v);
                  await this.prefs.putBoolean('video_preview_mute', v);
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })

            Divider().height(1).color(dividerColor(this.isDark)).margin({ left: 16 })

            Row() {
              Text('主贴画中画').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Text('后台小窗继续播放').fontFamily(this.appFontFamily).fontSize(12).fontColor(textTertiary(this.isDark)).margin({ left: 8 })
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.pipEnabled })
                .onChange(async (v) => {
                  this.pipEnabled = v;
                  AppStorage.SetOrCreate<boolean>('pipEnabled', v);
                  await this.prefs.putBoolean('pip_enabled', v);
                })
            }
            .width('100%').height(56).padding({ left: 16, right: 16 })

            Divider().height(1).color(dividerColor(this.isDark)).margin({ left: 16 })

            Row() {
              Text('列表画中画').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Text('列表预览滑出屏幕自动小窗').fontFamily(this.appFontFamily).fontSize(12).fontColor(textTertiary(this.isDark)).margin({ left: 8 })
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.videoListPip })
                .onChange(async (v) => {
                  this.videoListPip = v;
                  AppStorage.SetOrCreate<boolean>('videoListPip', v);
                  await this.prefs.putBoolean('video_list_pip', v);
                })
            }
            .width('100%').height(56).padding({ left: 16, right: 16 })
          }
          .width('100%').backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(8))

          Text('链接').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).width('100%').padding(16)

          Column() {
            Row() {
              Text('应用内打开链接').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.openLinksInApp })
                .onChange(async (v) => {
                  this.openLinksInApp = v;
                  await this.prefs.putBoolean('open_links_in_app', v);
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })
          }
          .width('100%').backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(8))

          Text('操作体验').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).width('100%').padding(16)

          Column() {
            Row() {
              Text('智感握姿').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Text('根据握持侧自动切换按钮位置').fontFamily(this.appFontFamily).fontSize(12).fontColor(textTertiary(this.isDark)).margin({ left: 8 })
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.gripEnabled })
                .onChange(async (v) => {
                  this.gripEnabled = v;
                  AppStorage.SetOrCreate<boolean>('gripEnabled', v);
                  if (!v) {
                    const cur = AppStorage.Get<number>('gripSide') || 0;
                    AppStorage.SetOrCreate<number>('gripSide', cur === 0 ? 1 : (cur === 1 ? 0 : 1));
                    AppStorage.SetOrCreate<number>('gripSide', 1);
                  }
                  await this.prefs.putBoolean('grip_enabled', v);
                })
            }
            .width('100%').height(56).padding({ left: 16, right: 16 })
            }
            .width('100%').backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(8))

          Column() {
            Row() {
              Text('FAB 圆角').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Text('0 直角 / 100 圆形').fontFamily(this.appFontFamily).fontSize(12).fontColor(textTertiary(this.isDark)).margin({ left: 8 })
              Blank()
              Text(String(this.fabRadius)).fontFamily(this.appFontFamily).fontSize(14).fontColor(textAccent(this.primaryColor, this.isDark)).margin({ right: 8 })
              Slider({ value: this.fabRadius, min: 0, max: 100, step: 1, style: SliderStyle.OutSet })
                .width(120)
                .onChange((value: number) => {
                  this.fabRadius = Math.round(value);
                  AppStorage.SetOrCreate<number>('fabRadius', this.fabRadius);
                  if (this.fabTimer !== -1) { clearTimeout(this.fabTimer); }
                  this.fabTimer = setTimeout(() => {
                    this.fabTimer = -1;
                    void this.prefs.putInt('fab_radius', this.fabRadius);
                  }, 400);
                })
            }
            .width('100%').height(56).padding({ left: 16, right: 16 })
          }
          .width('100%').backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(8)).margin({ top: 8 })
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
