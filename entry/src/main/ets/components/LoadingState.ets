import { textPrimary, textSecondary, textTertiary } from '../core/utils/DataHelper';
import GearLoading from './GearLoading';

@Component
export default struct LoadingState {
  @StorageLink('isDarkTheme') isDark: boolean = false;
  @StorageLink('fontScale') fontScale: number = 1.0;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @Prop message: string = '加载中...';
  
  build() {
    Column() {
      GearLoading({ gearSize: 40, color: '#4477E0' })
      Text(this.message)
        .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale))
        .fontColor(textTertiary(this.isDark))
        .margin({ top: 16 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
