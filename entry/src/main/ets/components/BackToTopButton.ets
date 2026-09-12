import display from '@ohos.display';
import { shadowColor, primaryContainer, onPrimaryContainer } from '../core/utils/DataHelper';
import { GripDetector } from '../core/utils/GripDetector';

@Component
export default struct BackToTopButton {
  @StorageLink('isDarkTheme') isDark: boolean = false;
  @StorageLink('fontScale') fontScale: number = 1.0;
  @StorageLink('gripSide') @Watch('onGripSideChanged') gripSide: number = 0;
  @StorageLink('fabRadius') fabRadius: number = 60;
  @Link @Watch('onScrollTopChange') scrollTop: number;
  onTopClick: () => void = () => {};
  @State showScrollTop: boolean = false;
  @State fabLeft: boolean = false;
  @State screenWidth: number = 360;
  private fabTimer: number = -1;
  private lastScrollTop: number = 0;

  aboutToAppear(): void {
    try {
      const d = display.getDefaultDisplaySync();
      if (d && d.width > 0) this.screenWidth = d.width / d.densityPixels;
    } catch (_e) {}
    this.lastScrollTop = this.scrollTop;
    this.onGripSideChanged();
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
        .backgroundColor(primaryContainer(this.isDark))
        .shadow({ radius: 6, color: shadowColor(this.isDark), offsetY: 3 })
        .position({ bottom: 64, right: 16 })
        .translate({ x: this.showScrollTop ? (this.fabLeft ? -(this.screenWidth - 76) : 0) : (this.fabLeft ? -(this.screenWidth - 76) - 60 : 60) })
        .onClick(() => { this.onTopClick(); })
    }
  }
}
