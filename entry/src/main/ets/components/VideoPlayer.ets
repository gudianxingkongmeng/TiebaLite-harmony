import media from '@ohos.multimedia.media';
import common from '@ohos.app.ability.common';
import display from '@ohos.display';
import { BusinessError } from '@ohos.base';
import PiPWindow from '@ohos.PiPWindow';
import promptAction from '@ohos.promptAction';
import VideoDownloader from '../core/utils/VideoDownloader';
import VideoCacheManager from '../core/utils/VideoCacheManager';
import VideoProgressStore from '../core/utils/VideoProgressStore';
import { NavigationHelper } from '../core/utils/NavigationHelper';

@Component
export default struct VideoPlayer {
  private static xcSeq: number = 0;
  private static screenH: number = 0;
  private static pipAutoRatio: number = 0.17;
  private player: media.AVPlayer | null = null;
  private playerGen: number = 0;
  private surfaceRetries: number = 0;
  private failTimer: number = -1;
  private controlsTimer: number = -1;
  private retryTimer: number = -1;
  private retryCount: number = 0;
  private xcId: string = '';
  @State isPlaying: boolean = false;
  @State isLoaded: boolean = false;
  @State hasError: boolean = false;
  @State lastErrCode: number = 0;
  @State boxW: number = 0;
  @State boxH: number = 0;
  @State durationSec: number = 0;
  @State currentSec: number = 0;
  @State showControls: boolean = true;
  @State showSpeedMenu: boolean = false;
  @State playSpeed: number = 1.0;
  private holdSpeed: number = 1.0;
  private speedOptions: number[] = [0.75, 1.0, 1.25, 1.5, 2.0];
  @Prop videoUrl: string = '';
  @Prop posterUrl: string = '';
  @Prop autoPlay: boolean = false;
  @Prop allowPip: boolean = true;
  @StorageLink('videoPreviewMute') @Watch('onMuteChange') muted: boolean = true;
  @Prop loop: boolean = false;
  @Prop isFullscreen: boolean = false;
  @Prop startPosition: number = 0;
  @Prop safeTop: number = 0;
  @Prop safeBottom: number = 0;
  @Prop videoAspect: number = 0;
  @State fullMuted: boolean = false;
  @State showInfoSheet: boolean = false;
  onRequestExit: (keepPip: boolean) => void = (keepPip: boolean) => {};
  onRequestRotate: () => void = () => {};
  @State curAspect: number = 0;
  @State loopActive: boolean = false;
  @State videoW: number = 0;
  @State videoH: number = 0;
  @Prop objectFit: ImageFit = ImageFit.Contain;
  @Prop videoWidth: number | string = '100%';
  @Prop videoHeight: number | string = 200;
  @Prop videoBorderRadius: number = 8;
  @Prop enableControls: boolean = true;
  onPositionChange: (sec: number) => void = (sec: number) => {};
  @StorageLink('isDarkTheme') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @StorageLink('videoResumeTick') @Watch('onResumeTick') resumeTick: number = 0;
  @StorageProp('previewActiveId') @Watch('onPreviewActiveChange') previewActiveId: string = '';
  @StorageLink('videoFullscreenActive') @Watch('onFullscreenActiveChange') fullscreenActive: boolean = false;
  @StorageProp('fullscreenPipClosedTick') @Watch('onPipClosedTick') pipClosedTick: number = 0;
  @StorageLink('videoVolumeKeyTick') @Watch('onVolumeKeyTick') volumeKeyTick: number = 0;
  @StorageProp('appInBackground') @Watch('onAppBgChange') appInBackground: boolean = false;
  @StorageProp('pageShowTick') @Watch('onPageShowTick') pageShowTick: number = 0;
  @StorageProp('pageHideTick') @Watch('onPageHideTick') pageHideTick: number = 0;
  private xcController: XComponentController = new XComponentController();
  private pendingResumePos: number = -1;
  private lastArea: Area | null = null;
  private pState: string = 'idle';
  private startedOnce: boolean = false;
  private visibleNow: boolean = true;
  private wasPlayingBeforeFullscreen: boolean = false;
  @StorageProp('previewClaimTick') @Watch('onClaimTick') claimTick: number = 0;
  @StorageLink('pipEnabled') pipEnabled: boolean = true;
  private pipController: PiPWindow.PiPController | null = null;
  private pipCreating: boolean = false;
  private pipStarting: boolean = false;
  private pipRestoring: boolean = false;
  private pipActive: boolean = false;
  private pipRequested: boolean = false;
  private resumeAfterPip: boolean = false;
  private pipSupported: boolean = false;
  private pipNavigateDone: boolean = false;
  private pipKeepAlive: boolean = false;
  private pipDelayTimer: number = -1;
  private disposed: boolean = false;
  private playingFromCache: boolean = false;
  private cacheWasComplete: boolean = false;
  private cacheDelayStarted: boolean = false;
  private forceNetwork: boolean = false;
  private enterResumePos: number = -1;
  private activeVideoUrl: string = '';
  private static readonly PIP_RETURN_GRACE_MS: number = 2500;

  private onAppBgChange(): void {
    if (!this.appInBackground || this.pipActive) return;
    if (AppStorage.get<string>('previewActiveId') === this.xcId) {
      AppStorage.SetOrCreate('previewActiveId', '');
      AppStorage.SetOrCreate('previewActiveVisible', false);
    }
    if (this.player && (this.pState === 'playing' || this.pState === 'buffering')) {
      console.info('TiebaLite: app background, pause video ' + this.xcId);
      this.saveProgress();
      try { this.player.pause(); } catch (e) {}
      this.isPlaying = false;
    }
  }

  private onClaimTick(): void {
    if (this.autoPlay && this.visibleNow && this.lastArea) {
      this.onAreaSelf(this.lastArea);
    }
  }

  private getPlayUrl(): string {
    return this.activeVideoUrl !== '' ? this.activeVideoUrl : String(this.videoUrl || '');
  }

  private onFullscreenActiveChange(): void {
    if (this.isFullscreen) return;
    if (this.fullscreenActive) {
      this.wasPlayingBeforeFullscreen = this.isPlaying || this.startedOnce;
      this.clearTimers();
      this.releasePlayer();
      this.isLoaded = false;
      this.isPlaying = false;
      this.hasError = false;
      this.pendingResumePos = -1;
    }
  }

  private onVisibilityChange(isFullyVisible: boolean): void {
    if (!this.autoPlay) return;
    if (isFullyVisible) {
      this.visibleNow = true;
      if (this.pipActive) {
        this.resumeAfterPip = true;
        void this.stopPipForList();
      }
      this.scheduleLeftoverPipClose();
      if (this.hasLeftoverFullscreenPip()) {
        console.info('TiebaLite: leftover fullscreen pip active, preview waits for it to close');
        return;
      }
      if (this.wasPlayingBeforeFullscreen && !this.fullscreenActive) {
        this.wasPlayingBeforeFullscreen = false;
        this.tryApplyResume(true);
        void this.initPlayer(true);
      } else if (this.lastArea) {
        this.onAreaSelf(this.lastArea);
      }
    } else {
      this.visibleNow = false;
      if (this.player && this.pState === 'playing' && this.allowPip && this.pipEnabled && this.pipSupported) {
        this.pipRequested = true;
        this.schedulePipForList();
        return;
      }
      if (AppStorage.get<string>('previewActiveId') === this.xcId) {
        AppStorage.SetOrCreate('previewActiveId', '');
        AppStorage.SetOrCreate('previewActiveVisible', false);
      }
      if (this.player && this.pState === 'playing') {
        this.saveProgress();
        try { this.player.pause(); } catch (e) {}
        this.isPlaying = false;
      }
    }
  }

  private cancelPendingPip(): void {
    if (this.pipDelayTimer >= 0) {
      clearTimeout(this.pipDelayTimer);
      this.pipDelayTimer = -1;
    }
    this.pipRequested = false;
  }

  private schedulePipForList(): void {
    if (this.pipDelayTimer >= 0) {
      clearTimeout(this.pipDelayTimer);
    }
    this.pipDelayTimer = setTimeout(() => {
      this.pipDelayTimer = -1;
      if (this.disposed) {
        this.pipRequested = false;
        return;
      }
      void this.startPipForList();
    }, 300);
  }

  private onMuteChange(): void {
    if (this.isFullscreen) return;
    if (this.player) {
      try { this.player.setVolume(this.muted ? 0 : 1); } catch (e) {}
    }
  }

  private onPageShowTick(): void {
    if (!this.autoPlay || this.isFullscreen) return;
    if (this.pipActive || this.pipStarting || this.pipRequested) return;
    if (this.hasLeftoverFullscreenPip()) {
      this.scheduleLeftoverPipClose();
      return;
    }
    if (this.lastArea && this.isFullyVisibleArea(this.lastArea)) {
      this.onAreaSelf(this.lastArea);
    }
  }

  private onPageHideTick(): void {
    if (!this.autoPlay || this.isFullscreen) return;
    if (this.pipActive || this.pipStarting) return;
    this.cancelPendingPip();
    if (this.player && this.pState === 'playing') {
      this.saveProgress();
      try { this.player.pause(); } catch (e) {}
      this.isPlaying = false;
    }
    if (AppStorage.get<string>('previewActiveId') === this.xcId) {
      AppStorage.SetOrCreate('previewActiveId', '');
      AppStorage.SetOrCreate('previewActiveVisible', false);
    }
  }

  private isFullyVisibleArea(a: Area): boolean {
    const gp = a.globalPosition;
    if (!gp || VideoPlayer.screenH <= 0) return false;
    const top = gp.y as number;
    const h = a.height as number;
    if (h <= 0) return false;
    return top >= 0 && (top + h) <= VideoPlayer.screenH;
  }

  aboutToAppear(): void {
    this.xcId = 'vps_' + String(VideoPlayer.xcSeq++);
    console.info('TiebaLite: [V8] aboutToAppear xcId=' + this.xcId + ' propUrlLen=' + String(this.videoUrl || '').length + ' posterLen=' + String(this.posterUrl || '').length + ' fullscreen=' + this.isFullscreen);
    try {
      this.pipSupported = PiPWindow.isPiPEnabled();
    } catch (e) {
      this.pipSupported = false;
    }
    if (this.isFullscreen && this.startPosition > 0) {
      this.pendingResumePos = this.startPosition;
    }
    this.loopActive = this.loop;
    if (!this.enableControls && this.videoUrl) {
      this.tryApplyResume(false);
    }
    if (this.autoPlay && VideoPlayer.screenH <= 0) {
      try {
        const d = display.getDefaultDisplaySync();
        const density = d.densityPixels > 0 ? d.densityPixels : 3;
        VideoPlayer.screenH = d.height / density;
      } catch (e) { VideoPlayer.screenH = 800; }
    }
  }

  aboutToDisappear(): void {
    this.disposed = true;
    this.cancelPendingPip();
    if (AppStorage.get<string>('previewActiveId') === this.xcId) {
      AppStorage.SetOrCreate('previewActiveId', '');
      AppStorage.SetOrCreate('previewActiveVisible', false);
    }
    if (this.pipKeepAlive) {
      console.info('TiebaLite: fullscreen page exit with pip alive, keep player running');
      this.clearTimers();
      return;
    }
    if (this.pipController) {
      void this.stopPipForList();
      this.teardownPip();
    }
    this.clearTimers();
    this.releasePlayer();
    this.pendingResumePos = -1;
  }

  private onAreaSelf(newArea: Area): void {
    if (!this.autoPlay || VideoPlayer.screenH <= 0 || !this.visibleNow) return;
    this.lastArea = newArea;
    const gp = newArea.globalPosition;
    if (!gp) return;
    const top = gp.y as number;
    const h = newArea.height as number;
    if (h <= 0) return;
    const bottom = top + h;
    const fullyVisible = top >= 0 && bottom <= VideoPlayer.screenH;
    const cur = AppStorage.get<string>('previewActiveId') || '';
    if (cur === this.xcId) {
      if (!fullyVisible) {
        const visibleH = Math.min(bottom, VideoPlayer.screenH) - Math.max(top, 0);
        if (visibleH > 0 && visibleH / h <= VideoPlayer.pipAutoRatio) {
          AppStorage.SetOrCreate('previewActiveId', '');
          AppStorage.SetOrCreate('previewActiveVisible', false);
          if (this.pipActive) return;
          if (this.player && this.pState === 'playing') {
            if (this.allowPip && this.pipEnabled && this.pipSupported) {
              this.pipRequested = true;
              void this.startPipForList();
            } else {
              this.saveProgress();
              try { this.player.pause(); } catch (e) {}
              this.isPlaying = false;
            }
          }
        }
      } else {
        AppStorage.SetOrCreate('previewActiveVisible', true);
      }
    } else if (fullyVisible) {
      const holderVisible = AppStorage.get<boolean>('previewActiveVisible') === true;
      if (!holderVisible) {
        AppStorage.SetOrCreate('previewActiveId', this.xcId);
        AppStorage.SetOrCreate('previewActiveVisible', true);
      }
    }
  }

  private onPreviewActiveChange(): void {
    if (!this.autoPlay) return;
    const active = this.previewActiveId === this.xcId;
    if (active) {
      if (this.appInBackground) return;
      if (this.hasLeftoverFullscreenPip()) {
        this.scheduleLeftoverPipClose();
        return;
      }
      if (this.hasError) {
        this.hasError = false;
        void this.initPlayer(true);
        return;
      }
      if (this.player && this.isLoaded && !this.isPlaying) {
        try { this.player.play(); } catch (e) {}
      }
    } else {
      if (this.pipActive || this.pipStarting || this.pipRequested) return;
      if (this.player && this.pState === 'playing') {
        this.saveProgress();
        try { this.player.pause(); } catch (e) {}
        this.isPlaying = false;
      }
    }
  }

  private tryApplyResume(checkPos: boolean): void {
    const url = AppStorage.get<string>('videoResumeUrl') || '';
    const pos = AppStorage.get<number>('videoResumePos') || 0;
    if (!url || url !== this.getPlayUrl() || pos <= 0) return;
    if (this.isLoaded && this.player) {
      try { this.player.seek(pos * 1000); } catch (e) {}
      this.pendingResumePos = -1;
    } else if (checkPos) {
      this.pendingResumePos = pos;
    }
  }

  private onResumeTick(): void {
    this.tryApplyResume(true);
  }

  async initPlayer(resetRetry: boolean = false): Promise<void> {
    if (!this.getPlayUrl()) return;
    console.info('TiebaLite: video initPlayer url=' + this.getPlayUrl() + ' fullscreen=' + this.isFullscreen + ' autoPlay=' + this.autoPlay + ' poster=' + this.posterUrl.length);
    this.clearTimers();
    if (resetRetry) this.retryCount = 0;
    const gen = ++this.playerGen;
    this.surfaceRetries = 0;
    this.hasError = false;
    this.cacheDelayStarted = false;
    try {
      this.releasePlayer();
      const player = await media.createAVPlayer();
      if (gen !== this.playerGen) {
        try { player.release(); } catch (e) {}
        return;
      }
      this.player = player;
      player.on('stateChange', (state: media.AVPlayerState) => {
        if (gen !== this.playerGen) return;
        this.pState = state;
        if (state === 'initialized') {
          this.tryBindSurface(player, gen);
        } else if (state === 'prepared') {
          console.info('TiebaLite: video prepared, durSec=' + (player.duration > 0 ? player.duration / 1000 : 0));
          this.durationSec = player.duration > 0 ? player.duration / 1000 : 0;
          this.isLoaded = true;
          this.hasError = false;
          this.retryCount = 0;
          this.forceNetwork = false;
          this.showControls = true;
          try {
            const vw = player.width as number;
            const vh = player.height as number;
            if (vw > 0 && vh > 0) this.curAspect = vw / vh;
            if (vw > 0) this.videoW = vw;
            if (vh > 0) this.videoH = vh;
          } catch (e) {}
          try { player.setVolume(this.isFullscreen ? (this.fullMuted ? 0 : 1) : (this.muted ? 0 : 1)); } catch (e) {}
          if (this.pendingResumePos > 0) {
            const target = this.playingFromCache && !this.cacheWasComplete &&
              this.pendingResumePos >= this.durationSec - 0.5
              ? Math.max(0, this.durationSec - 0.3)
              : this.pendingResumePos;
            try { player.seek(target * 1000); } catch (e) {}
            this.pendingResumePos = -1;
          } else {
            const saved = VideoProgressStore.get(this.getPlayUrl());
            if (saved > 3 && saved < this.durationSec - 2) {
              try { player.seek(saved * 1000); } catch (e) {}
            }
          }
          if (((this.autoPlay && this.previewActiveId === this.xcId) || this.isFullscreen) && !this.appInBackground) {
            console.info('TiebaLite: video auto play (fullscreen=' + this.isFullscreen + ')');
            try { player.play(); } catch (e) {}
          }
        } else if (state === 'playing') {
          this.isPlaying = true;
          this.startedOnce = true;
          this.scheduleHideControls();
          this.syncPipControl();
          if (gen === this.playerGen && !this.playingFromCache && !this.cacheDelayStarted) {
            this.cacheDelayStarted = true;
            setTimeout(() => {
              if (gen === this.playerGen) {
                VideoCacheManager.getInstance().startDownload(this.getPlayUrl(), getContext(this) as common.UIAbilityContext, this.isFullscreen);
              }
            }, 3000);
          }
        } else if (state === 'paused') {
          this.isPlaying = false;
          this.clearControlsTimer();
          this.syncPipControl();
        } else if (state === 'completed') {
          this.isPlaying = false;
          this.clearControlsTimer();
          if (this.loopActive) {
            try { player.seek(0); player.play(); } catch (e) {}
          } else if (this.playingFromCache && !this.cacheWasComplete) {
            console.info('TiebaLite: partial cache ended, switch to network at ' + this.currentSec);
            this.saveProgress();
            this.pendingResumePos = this.enterResumePos > 0 ? this.enterResumePos : (this.currentSec > 0 ? this.currentSec : 0);
            this.enterResumePos = -1;
            this.playingFromCache = false;
            this.forceNetwork = true;
            this.retryTimer = setTimeout(() => {
              this.retryTimer = -1;
              if (gen === this.playerGen) void this.initPlayer(true);
            }, 50);
          } else {
            VideoProgressStore.clear(this.getPlayUrl());
          }
        }
      });
      player.on('timeUpdate', (time: number) => {
        this.currentSec = time > 0 ? time / 1000 : 0;
        this.onPositionChange(this.currentSec);
      });
      player.on('error', (err: BusinessError) => {
        if (gen !== this.playerGen) return;
        console.info('TiebaLite: video player error event, code=' + err.code + ' msg=' + err.message + ' loaded=' + this.isLoaded);
        this.lastErrCode = err.code;
        if (this.playingFromCache) {
          console.info('TiebaLite: cached playback failed, fallback to network');
          if (this.cacheWasComplete) {
            try {
              VideoCacheManager.getInstance().invalidate(this.getPlayUrl(), getContext(this) as common.UIAbilityContext);
            } catch (e) {}
          }
          this.forceNetwork = true;
          this.retryCount = 0;
          this.retryTimer = setTimeout(() => {
            this.retryTimer = -1;
            if (gen === this.playerGen) void this.initPlayer();
          }, 100);
          return;
        }
        if (!this.isLoaded) {
          if (err.code === 5400102) {
            console.info('TiebaLite: ignore volume op error, continue');
            return;
          }
          this.failAndMaybeRetry(gen);
        }
      });
      let playUrl = this.getPlayUrl();
      this.playingFromCache = false;
      this.cacheWasComplete = false;
      if (!this.forceNetwork) {
        try {
          const ctx = getContext(this) as common.UIAbilityContext;
          const cached = VideoCacheManager.getInstance().getCachedPath(this.getPlayUrl(), ctx);
          if (cached) {
            playUrl = 'file://' + cached;
            this.playingFromCache = true;
            this.cacheWasComplete = true;
            console.info('TiebaLite: preview play from full cache');
          } else {
            const resumeAt = this.pendingResumePos > 0 ? this.pendingResumePos : (VideoProgressStore.get(this.getPlayUrl()) || 0);
            this.enterResumePos = resumeAt;
            let partial = VideoCacheManager.getInstance().getPartialCachedPath(this.getPlayUrl(), ctx);
            if (!partial) {
              VideoCacheManager.getInstance().startDownload(this.getPlayUrl(), ctx, this.isFullscreen);
              partial = await this.waitForPartialCache(this.getPlayUrl(), ctx, 1500, gen);
            }
            if (partial && gen === this.playerGen) {
              playUrl = 'file://' + partial;
              this.playingFromCache = true;
              console.info('TiebaLite: play from partial cache resumeAt=' + resumeAt);
            } else if (gen === this.playerGen) {
              VideoCacheManager.getInstance().startDownload(this.getPlayUrl(), ctx, this.isFullscreen);
              console.info('TiebaLite: network direct play resumeAt=' + resumeAt);
            }
          }
        } catch (e) {}
      }
      if (playUrl.startsWith('file://')) {
        player.url = playUrl;
      } else {
        try {
          const src = media.createMediaSourceWithUrl(playUrl, {
            'User-Agent': 'bdtb for Android 12.52.1.0',
            'Referer': 'https://tieba.baidu.com/'
          });
          await player.setMediaSource(src, {
            preferredBufferDurationForPlaying: 2,
            showFirstFrameOnPrepare: true
          } as media.PlaybackStrategy);
        } catch (e) {
          player.url = playUrl;
        }
      }
      if (this.failTimer === -1) {
        this.failTimer = setTimeout(() => {
          if (gen !== this.playerGen || this.isLoaded) { this.failTimer = -1; return; }
          const st = this.pState;
          if (st === 'preparing' || st === 'buffering' || st === 'initialized') {
            console.info('TiebaLite: load in progress state=' + st + ', extend timeout');
            this.failTimer = setTimeout(() => {
              this.failTimer = -1;
              if (gen === this.playerGen && !this.isLoaded) {
                if (this.autoPlay && this.previewActiveId !== this.xcId) return;
                this.failAndMaybeRetry(gen);
              }
            }, 25000);
            return;
          }
          this.failTimer = -1;
          if (gen === this.playerGen && !this.isLoaded) {
            if (this.autoPlay && this.previewActiveId !== this.xcId) return;
            this.failAndMaybeRetry(gen);
          }
        }, 15000);
      }
    } catch (e) {
      if (gen === this.playerGen) this.hasError = true;
    }
  }

  private waitForPartialCache(url: string, ctx: common.UIAbilityContext, timeoutMs: number, gen: number): Promise<string> {
    const mgr = VideoCacheManager.getInstance();
    return new Promise<string>((resolve) => {
      const deadline = Date.now() + timeoutMs;
      const tick = (): void => {
        if (gen !== this.playerGen) { resolve(''); return; }
        const p = mgr.getPartialCachedPath(url, ctx);
        if (p || Date.now() >= deadline) { resolve(p); return; }
        setTimeout(tick, 200);
      };
      tick();
    });
  }

  private failAndMaybeRetry(gen: number): void {
    if (gen !== this.playerGen || this.isLoaded || this.retryTimer !== -1) return;
    if (this.autoPlay && this.previewActiveId !== this.xcId) return;
    if (this.retryCount < 5) {
      this.retryCount++;
      this.releasePlayer();
      const delays: number[] = [1000, 2000, 3000, 5000, 8000];
      const delay = delays[Math.min(this.retryCount - 1, 4)];
      this.retryTimer = setTimeout(() => {
        this.retryTimer = -1;
        if (gen === this.playerGen) void this.initPlayer();
      }, delay);
    } else {
      this.hasError = true;
    }
  }

  private tryBindSurface(player: media.AVPlayer, gen: number): void {
    const surfaceId = this.xcController.getXComponentSurfaceId();
    if (surfaceId) {
      console.info('TiebaLite: video bind surface id=' + surfaceId);
      try { player.surfaceId = surfaceId; } catch (e) {}
      try { player.prepare(); } catch (e) {}
    } else if (gen === this.playerGen) {
      this.surfaceRetries++;
      if (this.surfaceRetries <= 3) {
        console.info('TiebaLite: video surface id not ready, retry=' + this.surfaceRetries);
      }
      if (this.surfaceRetries < 50) {
        setTimeout(() => { this.tryBindSurface(player, gen); }, 200);
      } else {
        this.failAndMaybeRetry(gen);
      }
    }
  }

  private saveProgress(): void {
    if (this.isLoaded) {
      VideoProgressStore.save(this.getPlayUrl(), Math.floor(this.currentSec));
    }
  }

  releasePlayer(): void {
    if (this.player) {
      this.saveProgress();
      try { this.player.off('stateChange'); } catch (e) {}
      try { this.player.off('timeUpdate'); } catch (e) {}
      try { this.player.off('error'); } catch (e) {}
      try { this.player.release(); } catch (e) {}
      this.player = null;
    }
  }

  private clearTimers(): void {
    if (this.failTimer !== -1) { clearTimeout(this.failTimer); this.failTimer = -1; }
    if (this.retryTimer !== -1) { clearTimeout(this.retryTimer); this.retryTimer = -1; }
    this.clearControlsTimer();
  }

  private clearControlsTimer(): void {
    if (this.controlsTimer !== -1) { clearTimeout(this.controlsTimer); this.controlsTimer = -1; }
  }

  private scheduleHideControls(): void {
    this.clearControlsTimer();
    this.controlsTimer = setTimeout(() => {
      this.controlsTimer = -1;
      if (this.isPlaying) {
        this.showControls = false;
        this.showSpeedMenu = false;
      }
    }, 3000);
  }

  private async togglePlay(): Promise<void> {
    if (this.anyLeftoverPip()) {
      this.stopLeftoverFullscreenPip();
    }
    if (!this.player) {
      await this.initPlayer(true);
    }
    if (!this.player) return;
    try {
      if (this.isPlaying) {
        await this.player.pause();
        this.clearControlsTimer();
      } else {
        await this.player.play();
        this.showControls = true;
        this.scheduleHideControls();
      }
    } catch (e) {}
  }

  private seekRelative(delta: number): void {
    if (!this.player || !this.isLoaded) return;
    const target = Math.max(0, Math.min(this.currentSec + delta, this.durationSec));
    try { this.player.seek(target * 1000); } catch (e) {}
    this.currentSec = target;
    this.showControls = true;
    this.scheduleHideControls();
  }

  private speedToEnum(s: number): number {
    if (s <= 0.75) return 0;
    if (s <= 1.0) return 1;
    if (s <= 1.25) return 2;
    if (s <= 1.5) return 3;
    return 4;
  }

  private setPlaySpeed(s: number): void {
    if (!this.player) return;
    try { this.player.setSpeed(this.speedToEnum(s)); this.playSpeed = s; } catch (e) {}
    this.showSpeedMenu = false;
    this.scheduleHideControls();
  }

  private setLongPressSpeed(on: boolean): void {
    if (!this.player || !this.isLoaded) return;
    if (on) {
      try { this.holdSpeed = this.playSpeed; this.player.setSpeed(4); this.playSpeed = 2.0; } catch (e) {}
    } else {
      try { this.player.setSpeed(this.speedToEnum(this.holdSpeed)); this.playSpeed = this.holdSpeed; } catch (e) {}
    }
  }

  private toggleLoop(): void {
    this.loopActive = !this.loopActive;
    if (this.player) {
      try { this.player.loop = this.loopActive; } catch (e) {}
    }
  }

  private saveCurrentVideo(): void {
    void VideoDownloader.saveVideo(this.getPlayUrl(), getContext(this) as common.UIAbilityContext);
  }

  private togglePreviewMute(): void {
    this.muted = !this.muted;
    if (this.player) {
      try { this.player.setVolume(this.muted ? 0 : 1); } catch (e) {}
    }
  }

  private toggleFullMute(): void {
    this.fullMuted = !this.fullMuted;
    if (this.player) {
      try { this.player.setVolume(this.fullMuted ? 0 : 1); } catch (e) {}
    }
  }

  private onVolumeKeyTick(): void {
    if (!this.isFullscreen) return;
    if (this.fullMuted) {
      this.fullMuted = false;
      if (this.player) {
        try { this.player.setVolume(1); } catch (e) {}
      }
    }
  }

  private openFullscreenFromPip(): void {
    if (this.pipNavigateDone) return;
    this.pipNavigateDone = true;
    console.info('TiebaLite: preview pip restore, open fullscreen');
    this.openFullscreen();
  }

  private openFullscreen(): void {
    console.info('TiebaLite: [V3] openFullscreen url=' + this.getPlayUrl() + ' fullscreen=' + this.isFullscreen);
    if (!this.getPlayUrl()) {
      console.info('TiebaLite: [V3] openFullscreen skipped, no url');
      return;
    }
    if (this.player && this.pState === 'playing') {
      try { this.player.pause(); } catch (e) {}
      this.isPlaying = false;
    }
    let aspect = 0;
    if (this.player && this.isLoaded) {
      try {
        const vw = this.player.width as number;
        const vh = this.player.height as number;
        if (vw > 0 && vh > 0) aspect = vw / vh;
      } catch (e) {}
    }
    AppStorage.SetOrCreate('previewActiveId', '');
    AppStorage.SetOrCreate('previewActiveVisible', false);
    NavigationHelper.navigate('pages/videoview/VideoViewPage', {
      videoUrl: this.getPlayUrl(),
      posterUrl: this.posterUrl,
      startPosition: Math.floor(this.currentSec),
      videoAspect: aspect,
      videoDuration: this.durationSec,
      allowPip: true
    });
  }

  private formatTime(seconds: number): string {
    const s = Math.floor(seconds);
    const m = Math.floor(s / 60);
    const sec = s % 60;
    return String(m) + ':' + (sec < 10 ? '0' + String(sec) : String(sec));
  }

  private surfaceSizeW(): number | string {
    const aspect = this.curAspect > 0 ? this.curAspect : this.videoAspect;
    if (aspect > 0 && this.boxW > 0 && this.boxH > 0) {
      if (aspect >= this.boxW / this.boxH) {
        return this.boxW;
      }
      return Math.floor(this.boxH * aspect);
    }
    return '100%';
  }

  private surfaceSizeH(): number | string {
    const aspect = this.curAspect > 0 ? this.curAspect : this.videoAspect;
    if (aspect > 0 && this.boxW > 0 && this.boxH > 0) {
      if (aspect >= this.boxW / this.boxH) {
        return Math.floor(this.boxW / aspect);
      }
      return this.boxH;
    }
    return '100%';
  }

  private pauseForScrollAway(): void {
    if (AppStorage.get<string>('previewActiveId') === this.xcId) {
      AppStorage.SetOrCreate('previewActiveId', '');
      AppStorage.SetOrCreate('previewActiveVisible', false);
    }
    if (this.player && this.pState === 'playing') {
      this.saveProgress();
      try { this.player.pause(); } catch (e) {}
      this.isPlaying = false;
    }
  }

  private scheduleLeftoverPipClose(): void {
    if (!this.anyLeftoverPip()) return;
    const start = AppStorage.get<number>('fullscreenPipStartTime') || 0;
    const elapsed = Date.now() - start;
    if (elapsed >= VideoPlayer.PIP_RETURN_GRACE_MS) {
      console.info('TiebaLite: leftover fullscreen pip grace expired, stop it');
      this.stopLeftoverFullscreenPip();
      return;
    }
    const wait = VideoPlayer.PIP_RETURN_GRACE_MS - elapsed;
    setTimeout(() => {
      if (this.visibleNow && this.anyLeftoverPip()) {
        this.stopLeftoverFullscreenPip();
      }
    }, wait);
  }

  private stopLeftoverFullscreenPip(): void {
    const ctrl = AppStorage.get<PiPWindow.PiPController | null>('fullscreenPipCtrl');
    if (!ctrl) return;
    console.info('TiebaLite: preview visible, stop leftover fullscreen pip');
    AppStorage.Delete('fullscreenPipCtrl');
    AppStorage.Delete('fullscreenPipUrl');
    AppStorage.Delete('fullscreenPipStartTime');
    try { void ctrl.stopPiP(); } catch (e) {}
  }

  private anyLeftoverPip(): boolean {
    const ctrl = AppStorage.get<PiPWindow.PiPController | null>('fullscreenPipCtrl');
    if (!ctrl) return false;
    return true;
  }

  private hasLeftoverFullscreenPip(): boolean {
    const ctrl = AppStorage.get<PiPWindow.PiPController | null>('fullscreenPipCtrl');
    if (!ctrl) return false;
    const ctrlUrl = AppStorage.get<string>('fullscreenPipUrl') || '';
    if (ctrlUrl && ctrlUrl !== this.getPlayUrl()) return false;
    return true;
  }

  private onPipClosedTick(): void {
    if (!this.autoPlay || !this.visibleNow || this.fullscreenActive) return;
    if (this.hasLeftoverFullscreenPip()) return;
    if (this.pipActive || this.pipStarting || this.pipRequested) return;
    const closedUrl = AppStorage.get<string>('fullscreenPipClosedUrl') || '';
    const closedPos = AppStorage.get<number>('fullscreenPipClosedPos') || 0;
    AppStorage.Delete('fullscreenPipClosedUrl');
    AppStorage.Delete('fullscreenPipClosedPos');
    console.info('TiebaLite: fullscreen pip closed, resume preview (closedUrl=' + closedUrl + ' pos=' + closedPos + ')');
    if (this.wasPlayingBeforeFullscreen) {
      this.wasPlayingBeforeFullscreen = false;
      AppStorage.SetOrCreate('previewActiveId', this.xcId);
      AppStorage.SetOrCreate('previewActiveVisible', true);
      if (closedUrl && closedPos > 0) {
        if (closedUrl !== this.getPlayUrl()) {
          this.activeVideoUrl = closedUrl;
        }
        this.pendingResumePos = closedPos;
      }
      this.tryApplyResume(true);
      void this.initPlayer(true);
    } else if (this.player && this.isLoaded && !this.isPlaying) {
      try { this.player.play(); } catch (e) {}
    }
  }

  private async ensurePipController(): Promise<PiPWindow.PiPController | null> {
    if (this.pipController) return this.pipController;
    if (this.pipCreating || !this.pipSupported) return null;
    this.pipCreating = true;
    try {
      let density = 3;
      try {
        const d = display.getDefaultDisplaySync();
        if (d.densityPixels > 0) density = d.densityPixels;
      } catch (e) {}
      const boxW = this.boxW > 0 ? this.boxW : 360;
      const boxH = this.boxH > 0 ? this.boxH : 200;
      const aspect = (this.curAspect > 0 ? this.curAspect : this.videoAspect) || (boxW / boxH) || (16 / 9);
      let cw = boxW;
      let ch = boxH;
      if (aspect >= boxW / boxH) {
        ch = boxW / aspect;
      } else {
        cw = boxH * aspect;
      }
      const w = Math.max(2, Math.floor(cw * density));
      const h = Math.max(2, Math.floor(ch * density));
      const config: PiPWindow.PiPConfiguration = {
        context: this.getUIContext().getHostContext() as common.UIAbilityContext,
        componentController: this.xcController,
        templateType: PiPWindow.PiPTemplateType.VIDEO_PLAY,
        contentWidth: w,
        contentHeight: h,
        defaultWindowSizeType: 1,
        cornerAdsorptionEnabled: true,
        controlGroups: [PiPWindow.VideoPlayControlGroup.FAST_FORWARD_BACKWARD]
      };
      const ctrl = await PiPWindow.create(config);
      if (!ctrl) return null;
      ctrl.on('stateChange', (state: PiPWindow.PiPState, reason: string) => {
        console.info('TiebaLite: pip state=' + state + ' reason=' + reason + (this.isFullscreen ? ' fullscreen' : ' preview'));
        if (this.isFullscreen) {
          if (state === PiPWindow.PiPState.ABOUT_TO_START) {
            this.pipStarting = true;
          } else if (state === PiPWindow.PiPState.STARTED) {
            this.pipStarting = false;
            this.pipActive = true;
            this.pipKeepAlive = true;
            AppStorage.SetOrCreate('fullscreenPipCtrl', ctrl);
            AppStorage.SetOrCreate('fullscreenPipUrl', this.videoUrl);
            AppStorage.SetOrCreate('fullscreenPipStartTime', Date.now());
            this.updateAutoStart();
            this.syncPipControl();
            this.onRequestExit(true);
          } else if (state === PiPWindow.PiPState.ABOUT_TO_RESTORE) {
            this.pipActive = false;
            this.pipRestoring = true;
            if (this.player && this.pState === 'playing') {
              console.info('TiebaLite: pip restore, pause leftover player');
              try { this.player.pause(); } catch (e) {}
            }
            setTimeout(() => { this.releasePlayer(); }, 500);
            AppStorage.Delete('fullscreenPipCtrl');
            AppStorage.Delete('fullscreenPipUrl');
            AppStorage.Delete('fullscreenPipStartTime');
            NavigationHelper.navigate('pages/videoview/VideoViewPage', {
              videoUrl: this.videoUrl,
              posterUrl: this.posterUrl,
              startPosition: Math.floor(this.currentSec),
              videoAspect: this.curAspect > 0 ? this.curAspect : this.videoAspect,
              videoDuration: this.durationSec,
              allowPip: true
            });
          } else if (state === PiPWindow.PiPState.STOPPED) {
            this.pipActive = false;
            this.pipStarting = false;
            this.pipRestoring = false;
            try { ctrl.setAutoStartEnabled(false); } catch (e) {}
            if (this.pipKeepAlive) {
              console.info('TiebaLite: fullscreen pip closed after page exit, release player');
              AppStorage.SetOrCreate('fullscreenPipClosedUrl', this.videoUrl);
              AppStorage.SetOrCreate('fullscreenPipClosedPos', Math.floor(this.currentSec));
              this.releasePlayer();
              this.teardownPip();
              this.pipKeepAlive = false;
              this.notifyPipClosed();
            } else if (!this.pipRestoring && this.player && this.pState === 'playing') {
              try { this.player.pause(); } catch (e) {}
              this.isPlaying = false;
            }
          } else if (state === PiPWindow.PiPState.ERROR) {
            this.pipActive = false;
            this.pipStarting = false;
            this.pipRestoring = false;
            try { ctrl.setAutoStartEnabled(false); } catch (e) {}
            if (this.pipKeepAlive) {
              this.releasePlayer();
              this.teardownPip();
              this.pipKeepAlive = false;
              this.notifyPipClosed();
            } else if (this.player && this.pState === 'playing') {
              try { this.player.pause(); } catch (e) {}
              this.isPlaying = false;
            }
          }
          return;
        }
        if (state === PiPWindow.PiPState.ABOUT_TO_START) {
          this.pipStarting = true;
        } else if (state === PiPWindow.PiPState.STARTED) {
          this.pipStarting = false;
          this.pipRequested = false;
          this.pipActive = true;
          AppStorage.SetOrCreate('previewActiveId', '');
          AppStorage.SetOrCreate('previewActiveVisible', false);
          this.syncPipControl();
        } else if (state === PiPWindow.PiPState.ABOUT_TO_RESTORE) {
          this.pipActive = false;
          this.pipRestoring = true;
          this.openFullscreenFromPip();
        } else if (state === PiPWindow.PiPState.STOPPED) {
          this.pipActive = false;
          this.pipStarting = false;
          if (this.resumeAfterPip) {
            this.resumeAfterPip = false;
          } else if (!this.pipRestoring && this.player && this.pState === 'playing') {
            try { this.player.pause(); } catch (e) {}
            this.isPlaying = false;
          }
          this.pipRestoring = false;
        } else if (state === PiPWindow.PiPState.ERROR) {
          this.pipActive = false;
          this.pipStarting = false;
          this.pipRestoring = false;
          this.resumeAfterPip = false;
          this.teardownPip();
          if (this.player && this.pState === 'playing') {
            try { this.player.pause(); } catch (e) {}
            this.isPlaying = false;
          }
        }
      });
      ctrl.on('controlEvent', (param: PiPWindow.ControlEventParam) => {
        console.info('TiebaLite: preview pip controlEvent type=' + param.controlType + ' status=' + param.status);
        if (param.controlType === PiPWindow.PiPControlType.VIDEO_PLAY_PAUSE) {
          if (param.status === PiPWindow.PiPControlStatus.PLAY) {
            this.pipResume();
          } else if (param.status === PiPWindow.PiPControlStatus.PAUSE) {
            this.pipPauseNow();
          }
        } else if (param.controlType === PiPWindow.PiPControlType.FAST_FORWARD) {
          this.seekRelative(10);
        } else if (param.controlType === PiPWindow.PiPControlType.FAST_BACKWARD) {
          this.seekRelative(-10);
        }
      });
      this.pipController = ctrl;
      return ctrl;
    } catch (e) {
      console.error('TiebaLite: preview pip create failed: ' + JSON.stringify(e));
      return null;
    } finally {
      this.pipCreating = false;
    }
  }

  private async startPipForList(): Promise<void> {
    if (this.isFullscreen) return;
    if (this.pipActive || this.pipStarting) return;
    if (!this.allowPip || !this.pipEnabled || !this.pipSupported) {
      this.pipRequested = false;
      this.pauseForScrollAway();
      return;
    }
    if (!this.player || this.pState !== 'playing') return;
    const ctrl = await this.ensurePipController();
    if (!ctrl) {
      if (this.pipRequested && !this.visibleNow) this.pauseForScrollAway();
      this.pipRequested = false;
      return;
    }
    this.pipStarting = true;
    try {
      await ctrl.startPiP();
    } catch (e) {
      this.pipStarting = false;
      this.pipRequested = false;
      console.error('TiebaLite: preview pip start failed: ' + JSON.stringify(e));
      this.teardownPip();
      if (!this.visibleNow) this.pauseForScrollAway();
    }
  }

  private async stopPipForList(): Promise<void> {
    if (!this.pipController) return;
    try {
      await this.pipController.stopPiP();
    } catch (e) {
      console.error('TiebaLite: preview pip stop failed: ' + JSON.stringify(e));
    }
  }

  private toggleFullscreenPip(): void {
    if (this.pipActive) {
      void this.stopPipForList();
      return;
    }
    void this.enterFullscreenPip();
  }

  private async enterFullscreenPip(): Promise<void> {
    console.info('TiebaLite: [PIP-M] btn allowPip=' + this.allowPip + ' player=' + (this.player !== null) + ' pState=' + this.pState + ' err=' + this.hasError + ' supported=' + this.pipSupported + ' enabled=' + this.pipEnabled + ' active=' + this.pipActive + ' starting=' + this.pipStarting + ' creating=' + this.pipCreating);
    if (!this.player || this.hasError) {
      promptAction.showToast({ message: '视频尚未就绪' });
      return;
    }
    if (!this.pipSupported) {
      promptAction.showToast({ message: '当前设备不支持画中画' });
      return;
    }
    if (!this.pipEnabled) {
      promptAction.showToast({ message: '画中画功能未开启' });
      return;
    }
    if (this.pipActive || this.pipStarting) return;
    const ctrl = await this.ensurePipController();
    if (!ctrl) {
      promptAction.showToast({ message: '画中画启动失败…' });
      return;
    }
    this.pipStarting = true;
    try {
      if (this.player && this.pState !== 'playing') {
        try { this.player.play(); } catch (e) {}
        await new Promise<void>((resolve: () => void) => {
          setTimeout(() => { resolve(); }, 600);
        });
      }
      console.info('TiebaLite: [PIP-M] startPiP pState=' + this.pState);
      await ctrl.startPiP();
    } catch (e) {
      this.pipStarting = false;
      console.error('TiebaLite: fullscreen pip start failed: ' + JSON.stringify(e));
      promptAction.showToast({ message: '画中画启动失败…' });
    }
  }

  private pipResume(): void {
    if (this.player && (this.pState === 'paused' || this.pState === 'prepared' ||
      this.pState === 'initialized' || this.pState === 'idle' || this.pState === 'completed')) {
      try { this.player.play(); } catch (e) {}
    }
  }

  private pipPauseNow(): void {
    if (this.player && (this.pState === 'playing' || this.pState === 'buffering')) {
      try { this.player.pause(); } catch (e) {}
    }
  }

  private syncPipControl(): void {
    if (!this.pipController) return;
    try {
      this.pipController.updatePiPControlStatus(PiPWindow.PiPControlType.VIDEO_PLAY_PAUSE,
        this.isPlaying ? PiPWindow.PiPControlStatus.PLAY : PiPWindow.PiPControlStatus.PAUSE);
    } catch (e) {}
  }

  private updateAutoStart(): void {
    if (!this.pipController) return;
    try {
      this.pipController.setAutoStartEnabled(this.isPlaying && !this.hasError);
    } catch (e) {}
  }

  private notifyPipClosed(): void {
    const t = AppStorage.get<number>('fullscreenPipClosedTick') || 0;
    AppStorage.SetOrCreate('fullscreenPipClosedTick', t + 1);
  }

  private teardownPip(): void {
    if (this.pipController) {
      try { this.pipController.off('stateChange'); } catch (e) {}
      try { this.pipController.off('controlEvent'); } catch (e) {}
      this.pipController = null;
    }
    this.pipActive = false;
    this.pipStarting = false;
    this.pipRestoring = false;
    this.pipRequested = false;
    this.resumeAfterPip = false;
    this.pipNavigateDone = false;
    this.pipKeepAlive = false;
  }

  build() {
    Stack() {
      XComponent({
        id: this.xcId,
        type: 'surface',
        controller: this.xcController
      })
        .width(this.surfaceSizeW())
        .height(this.surfaceSizeH())
        .onLoad(() => {
          console.info('TiebaLite: [V1] XComponent onLoad xcId=' + this.xcId + ' play=' + this.getPlayUrl() + ' propUrl=' + this.videoUrl + ' active=' + this.activeVideoUrl + ' fullscreen=' + this.isFullscreen);
          void this.initPlayer(true);
        })

      if (!this.isLoaded && !this.hasError) {
        Stack() {
          if (this.isFullscreen) {
            Stack() {
              if (this.posterUrl) {
                Image(this.posterUrl)
                  .width('100%').height('100%')
                  .objectFit(ImageFit.Contain)
                  .backgroundColor('#000000')
              }
              Column() {
                LoadingProgress().width(40).height(40).color('#FFFFFF')
                Text('视频加载中...').fontFamily(this.appFontFamily).fontSize(14).fontColor('#AAFFFFFF').margin({ top: 14 })
              }
              .width('100%').height('100%')
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            }
            .width('100%').height('100%')
            .backgroundColor('#000000')
          } else if (this.posterUrl) {
            Image(this.posterUrl)
              .width('100%').height('100%')
              .objectFit(ImageFit.Cover)
          } else {
            Column() {
              LoadingProgress().width(32).height(32).color('#FFFFFF')
            }
            .width('100%').height('100%')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .backgroundColor('#1A000000')
          }
          if (!this.isFullscreen && this.posterUrl) {
            Column() {
              LoadingProgress().width(28).height(28).color('#FFFFFF')
            }
            .width('100%').height('100%')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .hitTestBehavior(HitTestMode.Transparent)
          }
        }
        .width('100%').height('100%')
        .borderRadius(this.videoBorderRadius)
        .hitTestBehavior(HitTestMode.Transparent)
      } else if (this.isFullscreen && this.isLoaded && !this.isPlaying && !this.startedOnce) {
        Column() {
          Image($r('app.media.ic_play_circle')).width(64).height(64).fillColor('#E6FFFFFF')
          Text('点击播放').fontFamily(this.appFontFamily).fontSize(14).fontColor('#AAFFFFFF').margin({ top: 12 })
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#000000')
        .hitTestBehavior(HitTestMode.Transparent)
      } else if (!this.isFullscreen && this.isLoaded && !this.isPlaying && !this.startedOnce && this.posterUrl && this.previewActiveId !== this.xcId) {
        Image(this.posterUrl)
          .width('100%').height('100%')
          .objectFit(ImageFit.Cover)
          .borderRadius(this.videoBorderRadius)
          .hitTestBehavior(HitTestMode.Transparent)
      }

      if (this.hasError) {
        Column() {
          Text('视频加载失败').fontFamily(this.appFontFamily).fontSize(14).fontColor('#FFFFFF')
          Text('点击重试').fontFamily(this.appFontFamily).fontSize(12).fontColor('#4477E0').margin({ top: 8 })
            .padding({ left: 16, right: 16, top: 6, bottom: 6 })
            .border({ width: 1, color: '#4477E0' }).borderRadius(14)
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#33000000')
        .borderRadius(this.videoBorderRadius)
        .hitTestBehavior(HitTestMode.Block)
        .onClick(() => {
          this.hasError = false;
          void this.initPlayer(true);
        })
      }

      if (!this.isFullscreen && !this.isPlaying && !this.hasError) {
        Image($r('app.media.ic_play_circle')).width(48).height(48).fillColor('#FFFFFF')
      }

      if (!this.isFullscreen && this.enableControls && this.showControls && this.isLoaded && !this.hasError) {
        Column() {
        Row() {
          Blank()
          Row() {
            Image(this.muted ? $r('app.media.ic_volume_off') : $r('app.media.ic_volume_on')).width(17).height(17).fillColor('#FFFFFF')
          }
          .width(32).height(32)
          .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
          .backgroundColor('#66000000')
          .borderRadius(6)
          .margin({ left: 8 })
          .hitTestBehavior(HitTestMode.Block)
          .onClick(() => { this.togglePreviewMute(); })
          Row() {
            Image($r('app.media.ic_pip')).width(17).height(17).fillColor(this.pipActive ? '#4477E0' : '#FFFFFF')
          }
          .width(32).height(32)
          .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
          .backgroundColor('#66000000')
          .borderRadius(6)
          .margin({ left: 8 })
          .hitTestBehavior(HitTestMode.Block)
          .onClick(() => { this.toggleFullscreenPip(); })
          Row() {
            Image($r('app.media.ic_fullscreen')).width(17).height(17).fillColor('#FFFFFF')
          }
            .width(32).height(32)
            .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
            .backgroundColor('#66000000')
            .borderRadius(6)
            .margin({ left: 8 })
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => { this.openFullscreen(); })
          }
          .width('100%').padding({ left: 8, right: 8, top: 8 })

          if (this.showSpeedMenu) {
            Row() {
              Blank()
              ForEach(this.speedOptions, (s: number) => {
                Text(String(s) + 'x')
                  .fontFamily(this.appFontFamily).fontSize(13)
                  .fontColor(this.playSpeed === s ? '#4477E0' : '#FFFFFF')
                  .fontWeight(this.playSpeed === s ? FontWeight.Bold : FontWeight.Regular)
                  .textAlign(TextAlign.Center)
                  .width(44).height(32).lineHeight(32)
                  .backgroundColor('#66000000')
                  .hitTestBehavior(HitTestMode.Block)
                  .onClick(() => { this.setPlaySpeed(s); })
              }, (s: number) => String(s))
            }
            .width('100%').padding({ right: 8, top: 4 })
            .transition(TransitionEffect.opacity(0))
          }

          Blank().layoutWeight(1)

          Row() {
            Column() {
              if (this.isPlaying) {
                Row() {
                  Column().width(5).height(18).backgroundColor('#FFFFFF').borderRadius(2.5)
                  Column().width(5).height(18).backgroundColor('#FFFFFF').borderRadius(2.5).margin({ left: 6 })
                }
              } else {
                Image($r('app.media.ic_play')).width(16).height(16).fillColor('#FFFFFF')
              }
            }
            .width(32).height(32)
            .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => { void this.togglePlay(); })

            Text(this.formatTime(this.currentSec))
              .fontFamily(this.appFontFamily).fontSize(11).fontColor('#FFFFFF')
              .margin({ left: 4 })
            Slider({
              value: this.currentSec,
              min: 0,
              max: this.durationSec > 0 ? this.durationSec : 1,
              step: 0.1,
              style: SliderStyle.OutSet
            })
              .layoutWeight(1)
              .trackThickness(3)
              .blockColor('#FFFFFF')
              .trackColor('#66FFFFFF')
              .selectedColor('#4477E0')
              .margin({ left: 6, right: 6 })
              .hitTestBehavior(HitTestMode.Block)
              .onChange((val: number) => {
                if (this.player) {
                  try { this.player.seek(Math.floor(val * 1000)); } catch (e) {}
                }
                this.currentSec = val;
              })
            Text(this.formatTime(this.durationSec))
              .fontFamily(this.appFontFamily).fontSize(11).fontColor('#FFFFFF')
          }
          .width('100%').padding({ left: 8, right: 8, bottom: 4 })
        }
        .width('100%')
        .height('100%')
      }

      if (this.isFullscreen && this.showControls && !this.hasError) {
        Column() {
          Row() {
            Row() {
              Image($r('app.media.ic_arrow_back')).width(26).height(26).fillColor('#FFFFFF')
            }
            .width(40).height(40).borderRadius(20)
            .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => { this.onRequestExit(false); })
            Blank()
            Row() {
              Image($r('app.media.ic_download')).width(20).height(20).fillColor('#FFFFFF')
            }
            .width(40).height(40).borderRadius(20)
            .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => { this.saveCurrentVideo(); })
            Row() {
              Image(this.fullMuted ? $r('app.media.ic_volume_off') : $r('app.media.ic_volume_on')).width(20).height(20).fillColor('#FFFFFF')
            }
            .width(40).height(40).borderRadius(20)
            .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
            .margin({ left: 4 })
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => { this.toggleFullMute(); })
            if (this.allowPip) {
              Row() {
                Image($r('app.media.ic_pip')).width(20).height(20).fillColor(this.pipActive ? '#4477E0' : '#FFFFFF')
              }
              .width(40).height(40).borderRadius(20)
              .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
              .margin({ left: 4 })
              .hitTestBehavior(HitTestMode.Block)
              .onClick(() => { this.toggleFullscreenPip(); })
            }
            Row() {
              Image($r('app.media.ic_info')).width(20).height(20).fillColor('#FFFFFF')
            }
            .width(40).height(40).borderRadius(20)
            .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
            .margin({ left: 4 })
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => {
              this.showInfoSheet = true;
              if (this.isPlaying) { this.scheduleHideControls(); }
            })
          }
          .width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor('#8C000000')

          Row() {
            Column() {
              Stack({ alignContent: Alignment.Center }) {
                Image($r('app.media.ic_seek_back')).width(34).height(34)
                Text('10').fontFamily(this.appFontFamily).fontSize(13).fontColor('#EEFFFFFF').fontWeight(FontWeight.Bold)
              }
              .width(46).height(46)
              .backgroundColor('#66000000').borderRadius(23)
            }
            .width(46).height(52)
            .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => { this.seekRelative(-10); })

            Column() {
              if (this.isPlaying) {
                Row() {
                  Column().width(6).height(24).backgroundColor('#DDFFFFFF').borderRadius(3)
                  Column().width(6).height(24).backgroundColor('#DDFFFFFF').borderRadius(3).margin({ left: 10 })
                }
              } else {
                Image($r('app.media.ic_play')).width(30).height(30).fillColor('#DDFFFFFF')
              }
            }
            .width(52).height(52)
            .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
            .backgroundColor('#66000000').borderRadius(26)
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => { void this.togglePlay(); })
            .gesture(
              LongPressGesture({ duration: 400 }).onAction(() => {
                this.setLongPressSpeed(true);
              }).onActionEnd(() => {
                this.setLongPressSpeed(false);
              })
            )
            .margin({ left: 22, right: 22 })

            Column() {
              Stack({ alignContent: Alignment.Center }) {
                Image($r('app.media.ic_seek_forward')).width(34).height(34)
                Text('10').fontFamily(this.appFontFamily).fontSize(13).fontColor('#EEFFFFFF').fontWeight(FontWeight.Bold)
              }
              .width(46).height(46)
              .backgroundColor('#66000000').borderRadius(23)
            }
            .width(46).height(52)
            .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => { this.seekRelative(10); })
          }
          .alignItems(VerticalAlign.Center)
          .layoutWeight(1)

          if (this.showSpeedMenu) {
            Row() {
              ForEach(this.speedOptions, (s: number) => {
                Text(String(s) + 'x')
                  .fontFamily(this.appFontFamily).fontSize(14)
                  .fontColor(this.playSpeed === s ? '#4477E0' : '#FFFFFF')
                  .fontWeight(this.playSpeed === s ? FontWeight.Bold : FontWeight.Regular)
                  .textAlign(TextAlign.Center)
                  .layoutWeight(1)
                  .hitTestBehavior(HitTestMode.Block)
                  .onClick(() => {
                    this.setPlaySpeed(s);
                    if (this.isPlaying) { this.scheduleHideControls(); }
                  })
              }, (s: number) => String(s))
            }
            .width('100%').height(44).padding({ left: 8, right: 8 })
            .backgroundColor('#8C000000')
            .transition(TransitionEffect.opacity(0))
          }

          Column() {
            Slider({
              value: this.currentSec,
              min: 0,
              max: this.durationSec > 0 ? this.durationSec : 1,
              step: 1,
              style: SliderStyle.OutSet
            })
              .width('100%')
              .trackThickness(4)
              .blockColor('#FFFFFF')
              .trackColor('#66FFFFFF')
              .selectedColor('#4477E0')
              .hitTestBehavior(HitTestMode.Block)
              .onChange((value: number) => {
                if (this.player) {
                  try { this.player.seek(Math.floor(value * 1000)); } catch (e) {}
                }
                this.currentSec = value;
              })
          }
          .width('100%').padding({ left: 16, right: 16, bottom: 2 })

          Row() {
            Text(this.formatTime(this.currentSec) + ' / ' + this.formatTime(this.durationSec))
              .fontFamily(this.appFontFamily).fontSize(12).fontColor('#FFFFFF')
            Blank()
            Row() {
              Image($r('app.media.ic_play')).width(13).height(13).fillColor('#FFFFFF').rotate({ angle: 180 })
              Text(this.playSpeed === 1.0 ? '倍速' : this.playSpeed + 'x')
                .fontFamily(this.appFontFamily).fontSize(14).fontColor('#FFFFFF').margin({ left: 6 })
            }
            .padding({ left: 12, right: 12, top: 5, bottom: 5 })
            .backgroundColor('#66000000').borderRadius(6)
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => {
              this.showSpeedMenu = !this.showSpeedMenu;
              if (this.showSpeedMenu && this.isPlaying) { this.scheduleHideControls(); }
            })
            Row() {
              Image($r('app.media.ic_repeat')).width(19).height(19).fillColor(this.loopActive ? '#4477E0' : '#FFFFFF')
            }
            .width(36).height(32)
            .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
            .backgroundColor('#66000000').borderRadius(6)
            .margin({ left: 8 })
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => { this.toggleLoop(); })
            Row() {
              Image($r('app.media.ic_fullscreen')).width(18).height(18).fillColor('#FFFFFF')
            }
            .width(36).height(32)
            .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
            .backgroundColor('#66000000').borderRadius(6)
            .margin({ left: 8 })
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => {
              this.onRequestRotate();
              if (this.isPlaying) { this.scheduleHideControls(); }
            })
          }
          .width('100%').padding({ left: 16, right: 16, bottom: 10 })
        }
        .width('100%').height('100%')
        .transition(TransitionEffect.opacity(0))
      }
    }
    .width(this.videoWidth)
    .height(this.videoHeight)
    .borderRadius(this.videoBorderRadius)
    .clip(true)
    .onAreaChange((_old: Area, newValue: Area) => {
      const w = newValue.width as number;
      const h = newValue.height as number;
      if (w > 0 && h > 0 && (w !== this.boxW || h !== this.boxH)) {
        this.boxW = w;
        this.boxH = h;
      }
      this.onAreaSelf(newValue);
    })
    .onVisibleAreaChange([1.0, VideoPlayer.pipAutoRatio], (isExpanding: boolean, currentRatio: number) => {
      if (isExpanding && currentRatio >= 0.95) {
        this.onVisibilityChange(true);
      } else if (!isExpanding && currentRatio <= 0.3) {
        this.onVisibilityChange(false);
      }
    })
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        LongPressGesture({ duration: 400 })
          .onAction(() => { if (this.enableControls) { this.setLongPressSpeed(true); } })
          .onActionEnd(() => { if (this.enableControls) { this.setLongPressSpeed(false); } }),
        TapGesture({ count: 2 })
          .onAction(() => {
            if (this.isFullscreen) {
              void this.togglePlay();
            } else {
              this.openFullscreen();
            }
          }),
        TapGesture({ count: 1 })
          .onAction(() => {
            if (this.isFullscreen) {
              this.showControls = !this.showControls;
              this.showSpeedMenu = false;
              if (this.showControls && this.isPlaying) {
                this.scheduleHideControls();
              } else {
                this.clearControlsTimer();
              }
            } else if (this.enableControls) {
              this.showControls = true;
              void this.togglePlay();
            } else {
              void this.togglePlay();
            }
          })
      )
    )
    .bindSheet($$this.showInfoSheet, this.infoSheetBuilder(), {
      height: 260,
      showClose: false,
      dragBar: false,
      backgroundColor: Color.Transparent
    })
  }

  @Builder
  infoSheetBuilder() {
    Column() {
      Row() {
        Text('媒体信息').fontFamily(this.appFontFamily).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        Blank()
        Text('关闭').fontFamily(this.appFontFamily).fontSize(15).fontColor('#AAFFFFFF').onClick(() => { this.showInfoSheet = false; })
      }
      .width('100%').height(46).padding({ left: 4, right: 4 })

      Column() {
        Row() {
          Text('分辨率').fontFamily(this.appFontFamily).fontSize(14).fontColor('#AAFFFFFF').width(90)
          Text(this.videoW > 0 && this.videoH > 0 ? String(this.videoW) + 'x' + String(this.videoH) : '未知')
            .fontFamily(this.appFontFamily).fontSize(14).fontColor('#FFFFFF')
        }.width('100%').margin({ top: 6 })
        Row() {
          Text('时长').fontFamily(this.appFontFamily).fontSize(14).fontColor('#AAFFFFFF').width(90)
          Text(this.formatTime(this.durationSec)).fontFamily(this.appFontFamily).fontSize(14).fontColor('#FFFFFF')
        }.width('100%').margin({ top: 6 })
        Row() {
          Text('播放速度').fontFamily(this.appFontFamily).fontSize(14).fontColor('#AAFFFFFF').width(90)
          Text(this.playSpeed + 'x').fontFamily(this.appFontFamily).fontSize(14).fontColor('#FFFFFF')
        }.width('100%').margin({ top: 6 })
      }
      .width('100%').padding({ left: 8, bottom: 16 })
    }
    .padding({ left: 16, right: 16, top: 8, bottom: 12 })
    .backgroundColor('#111111')
    .borderRadius({ topLeft: 16, topRight: 16 })
  }
}
