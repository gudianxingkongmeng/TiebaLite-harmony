import { textPrimary, textSecondary, textTertiary } from '../core/utils/DataHelper';

@Component
export default struct ErrorState {
  @StorageLink('isDarkTheme') isDark: boolean = false;
  @StorageLink('fontScale') fontScale: number = 1.0;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @Prop message: string = '加载失败，请重试';
  onRetryAction: () => void = (): void => {};

  build() {
    Column() {
      Text('!')
        .fontFamily(this.appFontFamily).fontSize(Math.round(48 * this.fontScale))
        .fontColor('#FF4444')
      Text(this.message)
        .fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale))
        .fontColor(textSecondary(this.isDark))
        .margin({ top: 16 })
      if (this.onRetryAction) {
        Button('重试')
          .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale))
          .fontColor('#FFFFFF')
          .backgroundColor('#4477E0')
          .borderRadius(20)
          .width(120).height(40)
          .margin({ top: 24 })
          .onClick(() => { if (this.onRetryAction) this.onRetryAction(); })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
