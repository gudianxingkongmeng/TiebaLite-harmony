import router from '@ohos.router';
import window from '@ohos.window';
import display from '@ohos.display';
import audio from '@ohos.multimedia.audio';
import { KeyCode } from '@ohos.multimodalInput.keyCode';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import common from '@ohos.app.ability.common';
import VideoPlayer from '../../components/VideoPlayer';
import { setDarkStatusBar } from '../../core/utils/SystemBarHelper';

@Entry
@Component
struct VideoViewPage {
  @StorageLink('isDarkTheme') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @State videoUrl: string = '';
  @State posterUrl: string = '';
  @State startSec: number = 0;
  @State videoAspect: number = 16 / 9;
  @State totalDuration: number = 0;
  @State allowPip: boolean = true;
  @State isLandscape: boolean = false;
  @State statusBarH: number = 0;
  @State navBarH: number = 0;
  @State screenW: number = 0;
  @State screenH: number = 0;
  private isLeavingPage: boolean = false;
  private volMgr: audio.AudioVolumeManager | null = null;
  private mainWin: window.Window | null = null;
  private statusHideTimer: number = -1;

  private keepScreenOn(on: boolean): void {
    if (this.mainWin) {
      try { this.mainWin.setWindowKeepScreenOn(on); } catch (e) {}
    }
  }

  private scheduleStatusHide(): void {
    if (!this.isLandscape) return;
    if (this.statusHideTimer >= 0) {
      clearTimeout(this.statusHideTimer);
    }
    this.statusHideTimer = setTimeout(() => {
      this.statusHideTimer = -1;
      if (this.isLeavingPage) return;
      console.info('TiebaLite: video fullscreen, hide status bar');
      try {
        const win = this.mainWin;
        if (win) {
          win.setWindowSystemBarEnable([]).catch(() => {});
        }
      } catch (e) {}
    }, 3000);
  }

  private restoreStatusBar(): void {
    if (this.statusHideTimer >= 0) {
      clearTimeout(this.statusHideTimer);
      this.statusHideTimer = -1;
    }
    console.info('TiebaLite: video fullscreen exit, restore status bar');
    try {
      window.getLastWindow(getContext(this) as common.UIAbilityContext).then((w) => {
        try { w.setWindowSystemBarEnable(['status']).catch(() => {}); } catch (e) {}
      }).catch(() => {});
    } catch (e) {}
  }

  aboutToAppear(): void {
    AppStorage.SetOrCreate('videoFullscreenActive', true);
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      const rawUrl = (params.videoUrl as string) || '';
      this.videoUrl = rawUrl.startsWith('http://') ? 'https://' + rawUrl.substring(7) : rawUrl;
      this.posterUrl = (params.posterUrl as string) || '';
      this.startSec = Number(params.startPosition || 0) || 0;
      const paramDur = Number(params.videoDuration || 0);
      if (paramDur > 0) {
        this.totalDuration = Math.floor(paramDur);
      }
      const paramAspect = Number(params.videoAspect || 0);
      if (paramAspect > 0.05 && paramAspect < 20) {
        this.videoAspect = paramAspect;
      }
      if (params.allowPip === false) {
        this.allowPip = false;
      }
    }
    console.info('TiebaLite: VideoView page shell, url=' + this.videoUrl + ' start=' + this.startSec);
    void setDarkStatusBar(getContext(this));
    this.updateStatusBarHeight();
    this.updateScreenSize();
    this.initVolumeListener();
    try {
      window.getLastWindow(getContext(this) as common.UIAbilityContext).then((win) => {
        this.mainWin = win;
        this.keepScreenOn(true);
        win.on('windowSizeChange', () => {
          this.updateStatusBarHeight();
        });
        win.on('avoidAreaChange', (data: window.AvoidAreaOptions) => {
          if (data && data.type === window.AvoidAreaType.TYPE_SYSTEM && data.area &&
            data.area.topRect && data.area.topRect.height > 0) {
            console.info('TiebaLite: status bar shown by gesture, schedule hide');
            this.scheduleStatusHide();
          }
        });
        this.scheduleStatusHide();
      }).catch(() => {});
    } catch (e) {}
  }

  aboutToDisappear(): void {
    this.keepScreenOn(false);
    this.restoreStatusBar();
    AppStorage.SetOrCreate('videoFullscreenActive', false);
    this.removeVolumeListener();
  }

  onPageShow(): void {
    void setDarkStatusBar(getContext(this));
    this.updateStatusBarHeight();
    this.scheduleStatusHide();
  }

  onPageHide(): void {
    this.removeVolumeListener();
  }

  private updateStatusBarHeight(): void {
    try {
      window.getLastWindow(getContext(this) as common.UIAbilityContext).then((win) => {
        const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        if (area && area.topRect) {
          let h = area.topRect.height;
          try {
            const d = display.getDefaultDisplaySync();
            const density = d.densityPixels > 0 ? d.densityPixels : 3;
            h = h / density;
          } catch (e) {}
          if (h < 0) h = 0;
          if (h > 80) h = 80;
          this.statusBarH = h;
        }
        const navArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
        if (navArea && navArea.bottomRect) {
          let nh = navArea.bottomRect.height;
          try {
            const d = display.getDefaultDisplaySync();
            const density = d.densityPixels > 0 ? d.densityPixels : 3;
            nh = nh / density;
          } catch (e) {}
          if (nh < 0) nh = 0;
          if (nh > 80) nh = 80;
          this.navBarH = nh;
        }
      }).catch(() => {});
    } catch (e) {}
  }

  private updateScreenSize(): void {
    try {
      const d = display.getDefaultDisplaySync();
      const density = d.densityPixels > 0 ? d.densityPixels : 3;
      this.screenW = d.width / density;
      this.screenH = d.height / density;
    } catch (e) {}
  }

  private initVolumeListener(): void {
    try {
      const mgr = audio.getAudioManager().getVolumeManager();
      this.volMgr = mgr;
      mgr.on('volumeChange', (evt: audio.VolumeEvent) => {
        if (evt.volumeType === audio.AudioVolumeType.MEDIA && evt.updateUi) {
          const t = AppStorage.get<number>('videoVolumeKeyTick') || 0;
          AppStorage.SetOrCreate('videoVolumeKeyTick', t + 1);
        }
      });
    } catch (e) {}
  }

  private removeVolumeListener(): void {
    if (this.volMgr) {
      try { this.volMgr.off('volumeChange'); } catch (e) {}
      this.volMgr = null;
    }
  }

  private async setOrientation(landscape: boolean): Promise<void> {
    try {
      const win = await window.getLastWindow(getContext(this) as common.UIAbilityContext);
      await win.setPreferredOrientation(landscape ? window.Orientation.LANDSCAPE : window.Orientation.PORTRAIT);
      this.isLandscape = landscape;
      if (landscape) {
        this.scheduleStatusHide();
      } else {
        this.restoreStatusBar();
      }
      setTimeout(() => {
        this.updateStatusBarHeight();
        this.updateScreenSize();
      }, 300);
    } catch (e) {}
  }

  private toggleOrientation(): void {
    void this.setOrientation(!this.isLandscape);
  }

  private handleExit(keepPip: boolean): void {
    if (this.isLeavingPage) return;
    this.isLeavingPage = true;
    console.info('TiebaLite: video page exit, keepPip=' + keepPip);
    this.removeVolumeListener();
    this.keepScreenOn(false);
    this.restoreStatusBar();
    if (this.isLandscape) {
      void this.setOrientation(false);
    }
    NavigationHelper.markBack();
    router.back();
  }

  build() {
    Stack() {
      VideoPlayer({
        videoUrl: this.videoUrl,
        posterUrl: this.posterUrl,
        autoPlay: false,
        loop: false,
        allowPip: this.allowPip,
        isFullscreen: true,
        startPosition: this.startSec,
        videoAspect: this.videoAspect,
        safeTop: this.statusBarH,
        safeBottom: this.navBarH,
        videoWidth: '100%',
        videoHeight: '100%',
        videoBorderRadius: 0,
        onRequestExit: (keepPip: boolean) => {
          this.handleExit(keepPip);
        },
        onRequestRotate: () => {
          this.toggleOrientation();
        }
      })
    }
    .width('100%').height('100%')
    .backgroundColor('#000000')
    .focusable(true)
    .defaultFocus(true)
    .onKeyEvent((event: KeyEvent) => {
      if (event.type === KeyType.Down &&
        (event.keyCode === KeyCode.KEYCODE_VOLUME_UP || event.keyCode === KeyCode.KEYCODE_VOLUME_DOWN)) {
        const t = AppStorage.get<number>('videoVolumeKeyTick') || 0;
        AppStorage.SetOrCreate('videoVolumeKeyTick', t + 1);
      }
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  onBackPress(): boolean {
    this.handleExit(false);
    return true;
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
