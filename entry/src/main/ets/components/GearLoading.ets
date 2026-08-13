import GearCycle from './GearCycle';

@Component
export default struct GearLoading {
  @StorageLink('appFontFamily') appFontFamily: string = '';
  gearSize: number = 18;
  color: string = '#999999';
  text: string = '';

  build() {
    Row() {
      GearCycle({
        gearSize: this.gearSize + 6,
        color: this.color,
        containerColor: '#00000000',
        refreshing: true
      })
      if (this.text.length > 0) {
        Text(this.text)
          .fontFamily(this.appFontFamily).fontSize(14).fontColor(this.color)
          .margin({ left: 6 })
      }
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }
}
