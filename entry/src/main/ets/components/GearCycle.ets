import HarmonyRing from './HarmonyRing';

const N_PTS: number = 24;
const TAU: number = Math.PI * 2;

function sampleShape(rfn: (t: number) => number): number[] {
  const pts: number[] = [];
  for (let k = 0; k < N_PTS; k++) {
    const t = k * TAU / N_PTS;
    pts.push(rfn(t), 0);
  }
  const tmp: number[] = [];
  for (let k = 0; k < N_PTS; k++) {
    const t = k * TAU / N_PTS;
    tmp.push(pts[k * 2] * Math.cos(t) - pts[k * 2 + 1] * Math.sin(t));
    tmp.push(pts[k * 2] * Math.sin(t) + pts[k * 2 + 1] * Math.cos(t));
  }
  return tmp;
}

function polyR(t: number, n: number): number {
  const seg = TAU / n;
  const phase = (t + seg / 2) % seg - seg / 2;
  return Math.cos(Math.PI / n) / Math.cos(phase);
}

const SHAPES: number[][] = [
  sampleShape((t: number): number => 1),
  sampleShape((t: number): number => 0.6 + 0.4 * Math.pow(Math.abs(Math.cos(6 * t)), 0.6)),
  sampleShape((t: number): number => polyR(t, 9)),
  sampleShape((t: number): number => polyR(t, 5)),
  sampleShape((t: number): number => 0.62 + 0.38 * Math.pow(Math.abs(Math.cos(4 * t)), 0.5)),
  sampleShape((t: number): number => 0.72 * polyR(t, 4) + 0.28)
];

const MORPH_ORDER: number[] = [1, 2, 3, 4, 5];

@Component
export default struct GearCycle {
  @StorageLink('refreshStyle') @Watch('onRefreshStyleChange') refreshStyle: number = 0;
  gearSize: number = 56;
  color: string = '#4477E0';
  containerColor: string = '#FFFFFF';
  @Prop @Watch('onProgressChange') progress: number = 0;
  @Prop @Watch('onRefreshingChange') refreshing: boolean = false;

  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private canvasReady: boolean = false;
  private timer: number = -1;
  private morphT: number = 0;
  private morphIdx: number = 0;
  private spin: number = 0;

  aboutToAppear(): void {
    this.startTimerIfNeeded();
  }

  aboutToDisappear(): void {
    this.clearTimer();
  }

  private onRefreshStyleChange(): void {
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
    if (this.refreshing) {
      this.spin = (this.spin + 360 * 30 / 4666) % 360;
    }
    this.draw();
  }

  private easeOut(x: number): number {
    return 1 - Math.pow(1 - x, 3);
  }

  private draw(): void {
    if (!this.canvasReady || this.gearSize <= 0) return;
    const ctx = this.ctx;
    const half = this.gearSize / 2;
    ctx.clearRect(0, 0, this.gearSize, this.gearSize);
    ctx.beginPath();
    ctx.arc(half, half, half - 0.5, 0, TAU);
    ctx.fillStyle = this.containerColor;
    ctx.fill();
    if (this.refreshing) {
      const idxA = MORPH_ORDER[this.morphIdx];
      this.fillShape(SHAPES[idxA], SHAPES[idxA], 1, this.spin);
    } else {
      const p = Math.max(0, this.progress);
      const t = Math.min(1, p);
      const extra = p > 1 ? -(p - 1) * 180 : 0;
      this.fillShape(SHAPES[0], SHAPES[1], t, -t * 180 + extra);
    }
  }

  private fillShape(a: number[], b: number[], t: number, rot: number): void {
    const ctx = this.ctx;
    const half = this.gearSize / 2;
    const scale = half * 0.79 * 0.94;
    const cosR = Math.cos(rot * Math.PI / 180);
    const sinR = Math.sin(rot * Math.PI / 180);
    const xs: number[] = [];
    const ys: number[] = [];
    for (let i = 0; i < N_PTS; i++) {
      const ax = a[i * 2];
      const ay = a[i * 2 + 1];
      const bx = b[i * 2];
      const by = b[i * 2 + 1];
      const x = ax + (bx - ax) * t;
      const y = ay + (by - ay) * t;
      const rx = x * cosR - y * sinR;
      const ry = x * sinR + y * cosR;
      xs.push(half + rx * scale);
      ys.push(half + ry * scale);
    }
    this.drawSmoothPath(xs, ys);
  }

  private drawSmoothPath(xs: number[], ys: number[]): void {
    const ctx = this.ctx;
    const corner = 0.12;
    ctx.beginPath();
    ctx.moveTo(xs[0] + (xs[1] - xs[0]) * corner, ys[0] + (ys[1] - ys[0]) * corner);
    for (let i = 0; i < N_PTS; i++) {
      const next = (i + 1) % N_PTS;
      const sx = xs[i] + (xs[next] - xs[i]) * corner;
      const sy = ys[i] + (ys[next] - ys[i]) * corner;
      const ex = xs[next] + (xs[i] - xs[next]) * corner;
      const ey = ys[next] + (ys[i] - ys[next]) * corner;
      ctx.lineTo(sx, sy);
      ctx.quadraticCurveTo(xs[next], ys[next], ex, ey);
    }
    ctx.closePath();
    ctx.fillStyle = this.color;
    ctx.fill();
  }

  build() {
    if (this.refreshStyle === 1) {
      HarmonyRing({
        gearSize: this.gearSize,
        color: this.color,
        containerColor: this.containerColor,
        progress: this.progress,
        refreshing: this.refreshing
      })
    } else {
      Canvas(this.ctx)
        .width(this.gearSize)
        .height(this.gearSize)
        .onReady(() => {
          this.canvasReady = true;
          this.draw();
        })
    }
  }
}
