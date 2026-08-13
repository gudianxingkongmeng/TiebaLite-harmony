import GearCycle from './GearCycle';

@Component
export default struct PullToRefresh {
  @Prop reduceEffects: boolean = false;
  @Prop gearSize: number = 48;
  @Prop color: string = '#4477E0';
  @Prop containerColor: string = '#FFFFFF';
  @Watch('onIsRefreshingChange')
  @Prop isRefreshing: boolean = false;
  scroller?: Scroller = undefined;
  onRefresh: () => void = () => {};
  onTimeout: () => void = () => {};
  @BuilderParam content: () => void;

  @State pullOffset: number = 0;
  @State pullRefreshing: boolean = false;
  private lastY: number = 0;
  private touching: boolean = false;
  private refreshTimeoutId: number = -1;
  private static readonly REFRESH_TIMEOUT_MS: number = 5000;

  private onIsRefreshingChange(): void {
    this.clearRefreshTimeout();
    if (!this.isRefreshing && this.pullRefreshing) {
      this.pullRefreshing = false;
      animateTo({ duration: 180, curve: Curve.EaseOut }, (): void => {
        this.pullOffset = 70;
      });
      this.refreshTimeoutId = setTimeout((): void => {
        this.refreshTimeoutId = -1;
        animateTo({ duration: 250, curve: Curve.EaseOut }, (): void => {
          this.pullOffset = 0;
        });
      }, 220);
    }
  }

  private startRefreshTimeout(): void {
    this.clearRefreshTimeout();
    this.refreshTimeoutId = setTimeout((): void => {
      this.refreshTimeoutId = -1;
      if (this.pullRefreshing) {
        this.pullRefreshing = false;
        animateTo({ duration: 180, curve: Curve.EaseOut }, (): void => {
          this.pullOffset = 70;
        });
        setTimeout((): void => {
          animateTo({ duration: 250, curve: Curve.EaseOut }, (): void => {
            this.pullOffset = 0;
          });
        }, 220);
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
            const damp = this.pullOffset >= 70 ? 0.35 : 1;
            this.pullOffset = Math.min(150, Math.max(0, this.pullOffset + dy * damp));
          } else if (dy > 0) {
            if (this.scroller && this.scroller.currentOffset().yOffset > 0.5) {
              break;
            }
            this.pullOffset = Math.min(150, this.pullOffset + dy);
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
          if (this.reduceEffects) {
            animateTo({ duration: 200, curve: Curve.EaseOut }, (): void => {
              this.pullOffset = 0;
            });
          } else {
            this.pullRefreshing = true;
            this.startRefreshTimeout();
            if (this.onRefresh) {
              this.onRefresh();
            }
          }
        } else if (this.pullOffset > 0) {
          animateTo({ duration: 150, curve: Curve.EaseOut }, (): void => {
            this.pullOffset = 70;
          });
          setTimeout((): void => {
            animateTo({ duration: 200, curve: Curve.EaseOut }, (): void => {
              this.pullOffset = 0;
            });
          }, 170);
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

      if (!this.reduceEffects && (this.pullOffset > 0 || this.pullRefreshing)) {
        Column() {
          GearCycle({
            gearSize: this.gearSize,
            color: this.color,
            containerColor: this.containerColor,
            progress: this.pullRefreshing ? 1 : this.pullOffset / 70,
            refreshing: this.pullRefreshing
          })
        }
        .width('100%')
        .position({
          top: -20,
          left: 0, right: 0
        })
        .translate({ y: Math.min(150, this.pullOffset * 1.4) })
        .opacity(Math.min(1, this.pullOffset / 40))
        .zIndex(10)
      }
    }
    .width('100%').height('100%')
    .onTouch((e: TouchEvent): void => {
      this.handleTouch(e);
    })
  }
}
