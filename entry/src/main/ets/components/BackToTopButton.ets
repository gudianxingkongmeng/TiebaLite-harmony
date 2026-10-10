import display from '@ohos.display';
import { shadowColor, primaryContainer, onPrimaryContainer, glassBlurLevel, glassTintSurface, glassTintBorder, glassTintShadow } from '../core/utils/DataHelper';
import { GripDetector } from '../core/utils/GripDetector';
import { FabPositionManager, FabOffset } from '../core/utils/FabPositionManager';

@Component
export default struct BackToTopButton {
  @StorageLink('isDarkTheme') isDark: boolean = false;
  @StorageLink('headerAlpha') headerAlpha: number = 25;
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  @StorageLink('fontScale') fontScale: number = 1.0;
  @StorageLink('gripSide') @Watch('onGripSideChanged') gripSide: number = 0;
  @StorageLink('fabPositionResetTick') @Watch('onFabResetTick') fabResetTick: number = 0;
  @StorageLink('fabRadius') fabRadius: number = 60;
  @Link @Watch('onScrollTopChange') scrollTop: number;
  onTopClick: () => void = () => {};
  @State showScrollTop: boolean = false;
  @State fabLeft: boolean = false;
  @State screenWidth: number = 360;
  @State screenHeight: number = 640;
  @State fabDx: number = 0;
  @State fabDy: number = 0;
  private dragging: boolean = false;
  private dragMoved: boolean = false;
  private dragStartX: number = 0;
  private dragStartY: number = 0;
  private dragBaseDx: number = 0;
  private dragBaseDy: number = 0;
  private fabTimer: number = -1;
  private lastScrollTop: number = 0;

  aboutToAppear(): void {
    try {
      const d = display.getDefaultDisplaySync();
      if (d && d.width > 0) {
        this.screenWidth = d.width / d.densityPixels;
        this.screenHeight = d.height / d.densityPixels;
      }
    } catch (_e) {}
    this.lastScrollTop = this.scrollTop;
    this.onGripSideChanged();
    void FabPositionManager.load('backToTop').then((o: FabOffset) => {
      // X 轴固定贴右侧（旧版本可能存过非零 dx，这里强制归零）
      this.fabDx = 0;
      this.fabDy = o.dy;
    }).catch(() => {});
  }

  private clampDx(v: number): number {
    const min = 68 - this.screenWidth;
    return Math.max(min, Math.min(8, v));
  }

  private clampDy(v: number): number {
    const min = 148 - this.screenHeight;
    return Math.max(min, Math.min(56, v));
  }

  private handleDragStart(e: GestureEvent): void {
    this.dragging = true;
    this.dragMoved = false;
    this.dragStartX = e.fingerList.length > 0 ? e.fingerList[0].globalX : 0;
    this.dragStartY = e.fingerList.length > 0 ? e.fingerList[0].globalY : 0;
    this.dragBaseDx = this.fabDx;
    this.dragBaseDy = this.fabDy;
  }

  private handleDragUpdate(e: GestureEvent): void {
    if (!this.dragging || e.fingerList.length === 0) {
      return;
    }
    const x = e.fingerList[0].globalX;
    const y = e.fingerList[0].globalY;
    if (Math.abs(x - this.dragStartX) > 3 || Math.abs(y - this.dragStartY) > 3) {
      this.dragMoved = true;
    }
    this.fabDx = this.clampDx(this.dragBaseDx + (x - this.dragStartX));
    this.fabDy = this.clampDy(this.dragBaseDy + (y - this.dragStartY));
  }

  private handleDragEnd(): void {
    if (!this.dragging) {
      return;
    }
    this.dragging = false;
    if (!this.dragMoved) {
      return;
    }
    // X 轴允许拖动，但松手后自动归位到侧边，只保留 Y 轴位置。
    // 用动画归零，视觉上更自然；持久化时 dx 固定存 0。
    animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
      this.fabDx = 0;
    });
    void FabPositionManager.save('backToTop', 0, this.fabDy).catch(() => {});
  }

  private handleResetPosition(): void {
    animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
      this.fabDx = 0;
      this.fabDy = 0;
    });
    void FabPositionManager.save('backToTop', 0, 0).catch(() => {});
  }

  onFabResetTick(): void {
    this.handleResetPosition();
  }

  onScrollTopChange(): void {
    const delta = this.scrollTop - this.lastScrollTop;
    if (delta > 5 && this.showScrollTop && this.scrollTop > 500) {
      animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
        this.showScrollTop = false;
      });
    } else if (delta < -5 && !this.showScrollTop && this.scrollTop > 500) {
      animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
        this.showScrollTop = true;
      });
    }
    this.lastScrollTop = this.scrollTop;
  }

  onGripSideChanged(): void {
    if (!GripDetector.isEnabled()) {
      if (this.fabLeft) this.fabLeft = false;
      return;
    }
    if (this.gripSide === -1 && !this.fabLeft) {
      this.switchFabSide(true);
    } else if (this.gripSide === 1 && this.fabLeft) {
      this.switchFabSide(false);
    }
  }

  private switchFabSide(toLeft: boolean): void {
    if (this.fabLeft === toLeft) return;
    if (this.fabTimer !== -1) { clearTimeout(this.fabTimer); }
    if (!this.showScrollTop) {
      this.fabLeft = toLeft;
      return;
    }
    const wasVisible = this.showScrollTop;
    animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
      this.showScrollTop = false;
    });
    this.fabTimer = setTimeout(() => {
      this.fabTimer = -1;
      this.fabLeft = toLeft;
      if (wasVisible) {
        animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
          this.showScrollTop = true;
        });
      }
    }, 250);
  }

  build() {
    if (this.scrollTop > 100) {
      Image($r('app.media.ic_arrow_up'))
        .width(Math.round(22 * this.fontScale)).height(Math.round(22 * this.fontScale))
        .fillColor(onPrimaryContainer(this.isDark))
        .width(44).height(44).borderRadius(22 * this.fabRadius / 100)
        .backgroundColor(glassTintSurface(this.primaryColor, this.isDark, this.headerAlpha))
        .backdropBlur(glassBlurLevel(this.headerAlpha))
        .border({ width: 1, color: glassTintBorder(this.primaryColor, this.isDark, this.headerAlpha) })
        .shadow({ radius: 10, color: glassTintShadow(this.primaryColor, this.isDark, this.headerAlpha), offsetY: 3 })
        .position({ bottom: 64, right: 16 })
        .translate({ x: (this.showScrollTop ? (this.fabLeft ? -(this.screenWidth - 76) : 0) : (this.fabLeft ? -(this.screenWidth - 76) - 60 : 60)) + this.fabDx, y: this.fabDy })
        .gesture(
          PanGesture({ fingers: 1, distance: 2 })
            .onActionStart((e: GestureEvent): void => { this.handleDragStart(e); })
            .onActionUpdate((e: GestureEvent): void => { this.handleDragUpdate(e); })
            .onActionEnd((): void => { this.handleDragEnd(); })
        )
        .onClick(() => {
          if (this.dragMoved) {
            this.dragMoved = false;
            return;
          }
          this.onTopClick();
        })
    }
  }
}
