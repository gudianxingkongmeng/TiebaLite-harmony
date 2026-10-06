import hilog from '@ohos.hilog';

const TAU: number = Math.PI * 2;

const LOG_DOMAIN: number = 0x0001;
const LOG_TAG: string = 'TBL-RING';

@Component
export default struct HarmonyRing {
  @StorageLink('reduceEffects') @Watch('onReduceChange') reduceEffects: boolean = false;
  gearSize: number = 48;
  color: string = '#4477E0';
  containerColor: string = '#FFFFFF';
  @Prop @Watch('onProgressChange') progress: number = 0;
  @Prop @Watch('onRefreshingChange') refreshing: boolean = false;

  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private canvasReady: boolean = false;
  private timer: number = -1;
  private spin: number = 0;

  aboutToAppear(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'appear gearSize=%{public}d refreshing=%{public}s', this.gearSize, this.refreshing);
    this.startTimerIfNeeded();
  }

  aboutToDisappear(): void {
    this.clearTimer();
  }

  private onReduceChange(): void {
    this.startTimerIfNeeded();
    this.draw();
  }

  private onProgressChange(): void {
    this.draw();
  }

  private onRefreshingChange(): void {
    this.startTimerIfNeeded();
    this.draw();
  }

  private startTimerIfNeeded(): void {
    if (this.refreshing && this.timer === -1) {
      this.timer = setInterval(() => { this.tick(); }, 30);
    } else if (!this.refreshing) {
      this.clearTimer();
    }
  }

  private clearTimer(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private tick(): void {
    this.spin = (this.spin + 360 * 30 / 1200) % 360;
    this.draw();
  }

  private draw(): void {
    try {
      if (!this.canvasReady || this.gearSize <= 0) return;
      const ctx = this.ctx;
      const half = this.gearSize / 2;
      const s = 0.55;
      ctx.clearRect(0, 0, this.gearSize, this.gearSize);
      ctx.beginPath();
      ctx.arc(half, half, (half - 0.5) * s, 0, TAU);
      ctx.fillStyle = this.containerColor;
      ctx.fill();
      const r = half * 0.8 * s;
      const phi = -Math.PI / 6;
      const a = r * 1.4;
      const b = r * 0.36;
      let angle: number;
      if (this.refreshing) {
        angle = -Math.PI / 2 - this.spin * Math.PI / 180;
      } else {
        const p = Math.min(1, Math.max(0, this.progress));
        angle = -Math.PI / 2 - p * TAU;
      }
      ctx.beginPath();
      ctx.arc(half, half, r, 0, TAU);
      ctx.strokeStyle = this.color;
      ctx.globalAlpha = 0.18;
      ctx.lineWidth = Math.max(2, half * 0.12 * s);
      ctx.stroke();
      ctx.globalAlpha = 1;
      const tail = 1.4;
      const segs = 24;
      const headW = Math.max(2.5, half * 0.26 * 2 / 3);
      const tailW = Math.max(1.5, half * 0.07);
      for (let i = 0; i < segs; i++) {
        const a0 = angle + tail * i / segs;
        const a1 = angle + tail * (i + 1) / segs;
        const t = 1 - i / segs;
        const alpha = 0.05 + 0.95 * Math.pow(t, 1.6);
        const w = tailW + (headW - tailW) * Math.pow(t, 1.6);
        ctx.beginPath();
        ctx.ellipse(half, half, a, b, phi, a0, a1);
        ctx.strokeStyle = this.color;
        ctx.globalAlpha = alpha;
        ctx.lineWidth = w;
        ctx.lineCap = 'round';
        ctx.stroke();
      }
      ctx.globalAlpha = 1;
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'draw EXCEPTION: %{public}s', (e as Error).message);
    }
  }

  build() {
    Canvas(this.ctx)
      .width(this.gearSize)
      .height(this.gearSize)
      .onReady(() => {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'onReady gearSize=%{public}d', this.gearSize);
        this.canvasReady = true;
        this.draw();
      })
  }
}
