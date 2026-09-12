import GearCycle from './GearCycle';
import HarmonyRing from './HarmonyRing';

@Component
export default struct RefreshAnimation {
  @StorageLink('refreshStyle') refreshStyle: number = 0;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @StorageLink('fontScale') fontScale: number = 1.0;
  @Prop refreshing: boolean = false;
  @Prop gearSize: number = 32;
  @Prop color: string = '#4477E0';
  @Prop containerColor: string = '#FFFFFF';
  @Prop text: string = '';

  build() {
    if (this.refreshing) {
      Row() {
        if (this.refreshStyle === 1) {
          HarmonyRing({
            gearSize: this.gearSize,
            color: this.color,
            containerColor: this.containerColor,
            refreshing: true
          })
        } else {
          GearCycle({
            gearSize: this.gearSize,
            color: this.color,
            containerColor: this.containerColor,
            refreshing: true
          })
        }
        if (this.text.length > 0) {
          Text(this.text)
            .fontFamily(this.appFontFamily)
            .fontSize(Math.round(14 * this.fontScale))
            .fontColor(this.color)
            .margin({ left: 6 })
        }
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .width('100%').padding(16)
    }
  }
}
