import HarmonyRing from './HarmonyRing';
import GearCycle from './GearCycle';
import hilog from '@ohos.hilog';

const LOG_DOMAIN: number = 0x0001;
const LOG_TAG: string = 'TBL-PTR';

@Component
export default struct PullToRefresh {
  @StorageLink('refreshStyle') refreshStyle: number = 0;
  @Prop reduceEffects: boolean = false;
  @Prop gearSize: number = 48;
  @Prop iconTopOffset: number = 0;
  @Prop color: string = '#4477E0';
  @Prop containerColor: string = '#FFFFFF';
  @Watch('onIsRefreshingChange')
  @Prop isRefreshing: boolean = false;
  scroller?: Scroller = undefined;
  onRefresh: () => void = () => {};
  onTimeout: () => void = () => {};
  @BuilderParam content: () => void;

  @State @Watch('onPullOffsetChange') pullOffset: number = 0;
  @State pullRefreshing: boolean = false;
  private lastY: number = 0;
  private touching: boolean = false;
  private refreshTimeoutId: number = -1;
  private static readonly MAX_PULL: number = 200;
  private static readonly REFRESH_TIMEOUT_MS: number = 5000;

  private onPullOffsetChange(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'pullOffset=%{public}d refreshStyle=%{public}d pullRefreshing=%{public}s',
      Math.round(this.pullOffset), this.refreshStyle, this.pullRefreshing);
  }

  private onIsRefreshingChange(): void {
    this.clearRefreshTimeout();
    if (!this.isRefreshing && this.pullRefreshing) {
      this.pullRefreshing = false;
      animateTo({ duration: 300, curve: Curve.EaseOut }, (): void => {
        this.pullOffset = 0;
      });
    }
  }

  private startRefreshTimeout(): void {
    this.clearRefreshTimeout();
    this.refreshTimeoutId = setTimeout((): void => {
      this.refreshTimeoutId = -1;
      if (this.pullRefreshing) {
        this.pullRefreshing = false;
        animateTo({ duration: 300, curve: Curve.EaseOut }, (): void => {
          this.pullOffset = 0;
        });
        if (this.onTimeout) {
          this.onTimeout();
        }
      }
    }, PullToRefresh.REFRESH_TIMEOUT_MS);
  }

  private clearRefreshTimeout(): void {
    if (this.refreshTimeoutId >= 0) {
      clearTimeout(this.refreshTimeoutId);
      this.refreshTimeoutId = -1;
    }
  }

  aboutToAppear(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'appear refreshStyle=%{public}d gearSize=%{public}d', this.refreshStyle, this.gearSize);
    this.clearRefreshTimeout();
  }

  aboutToDisappear(): void {
    this.clearRefreshTimeout();
  }

  private handleTouch(e: TouchEvent): void {
    if (e.touches.length === 0) {
      return;
    }
    switch (e.type) {
      case TouchType.Down:
        this.touching = true;
        this.lastY = e.touches[0].windowY;
        break;
      case TouchType.Move:
        if (!this.touching || this.pullRefreshing) {
          break;
        }
        {
          const y = e.touches[0].windowY;
          const dy = y - this.lastY;
          this.lastY = y;
          if (this.pullOffset > 0) {
            const damp = this.pullOffset >= 70 ? 0.45 : 1;
            this.pullOffset = Math.min(PullToRefresh.MAX_PULL, Math.max(0, this.pullOffset + dy * damp));
          } else if (dy > 0) {
            if (this.scroller && this.scroller.currentOffset().yOffset > 0.5) {
              break;
            }
            this.pullOffset = Math.min(PullToRefresh.MAX_PULL, this.pullOffset + dy);
          }
        }
        break;
      case TouchType.Up:
      case TouchType.Cancel:
        if (!this.touching) {
          break;
        }
        this.touching = false;
        if (this.pullRefreshing) {
          break;
        }
        if (this.pullOffset >= 70) {
          this.pullRefreshing = true;
          this.startRefreshTimeout();
          if (this.onRefresh) {
            this.onRefresh();
          }
        } else if (this.pullOffset > 0) {
          animateTo({ duration: 300, curve: Curve.EaseOut }, (): void => {
            this.pullOffset = 0;
          });
        }
        break;
    }
  }

  build() {
    Stack() {
      Column() {
        this.content()
      }
      .width('100%').height('100%')
      .translate({ y: this.refreshStyle === 1 ? this.pullOffset : 0 })

      if (this.pullOffset > 0 || this.pullRefreshing) {
        Column() {
          if (this.refreshStyle === 1) {
            HarmonyRing({
              gearSize: this.gearSize,
              color: this.color,
              containerColor: this.containerColor,
              progress: this.pullRefreshing ? 1 : this.pullOffset / 70,
              refreshing: this.pullRefreshing || this.pullOffset > 0
            })
          } else {
            GearCycle({
              gearSize: this.gearSize,
              color: this.color,
              containerColor: this.containerColor,
              progress: this.pullRefreshing ? 1 : this.pullOffset / 70,
              refreshing: this.pullRefreshing
            })
          }
        }
        .width('100%')
        .position({
          top: -20,
          left: 0, right: 0
        })
        .translate({ y: this.refreshStyle === 1 ? this.iconTopOffset + 30 : Math.min(PullToRefresh.MAX_PULL, this.pullOffset * 1.4) })
        .opacity(this.refreshStyle === 1 ? Math.min(1, this.pullOffset / 30) : Math.min(1, this.pullOffset / 40))
        .zIndex(10)
      }
    }
    .width('100%').height('100%')
    .onTouch((e: TouchEvent): void => {
      this.handleTouch(e);
    })
  }
}
