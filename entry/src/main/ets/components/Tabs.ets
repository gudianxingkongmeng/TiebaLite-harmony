import { blendWithWhite, darkenColor, blendWithBg, pageBg, cardBg, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../core/utils/DataHelper';

@Component
export default struct SimpleTabs {
  @Prop tabs: string[] = [];
  @State selectedIndex: number = 0;
  onTabChange?: (index: number) => void;
  @BuilderParam tabContent: () => void;
  @StorageLink('isDarkTheme') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  
  build() {
    Column() {
      Row() {
        ForEach(this.tabs, (tab: string, index: number) => {
          Column() {
            Text(tab)
              .fontFamily(this.appFontFamily).fontSize(15)
              .fontColor(index === this.selectedIndex ? '#4477E0' : textSecondary(this.isDark))
              .fontWeight(index === this.selectedIndex ? FontWeight.Medium : FontWeight.Regular)
            
            if (index === this.selectedIndex) {
              Divider()
                .color('#4477E0')
                .width('60%')
                .height(3)
                .borderRadius(1.5)
            }
          }
          .height(44)
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.selectedIndex = index;
            if (this.onTabChange) this.onTabChange(index);
          })
        })
      }
      .width('100%')
      .backgroundColor(cardBg(this.isDark))
      
      this.tabContent()
    }
    .width('100%')
    .height('100%')
  }
}
