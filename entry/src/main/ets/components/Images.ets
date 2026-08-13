import { blendWithWhite, darkenColor, blendWithBg, pageBg, cardBg, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../core/utils/DataHelper';

@Component
export default struct NetworkImage {
  @Prop src: string = '';
  @Prop imageWidth: number | string = '100%';
  @Prop imageHeight: number | string = 200;
  @Prop imageBorderRadius: number = 0;
  @Prop objectFit: ImageFit = ImageFit.Cover;
  @State loaded: boolean = false;
  @State failed: boolean = false;
  @State forceLoaded: boolean = false;
  @StorageLink('isDarkTheme') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @StorageLink('imageLoadMode') imageLoadMode: number = 0;
  @StorageLink('netIsWifi') netIsWifi: boolean = true;

  private imgAllowed(): boolean {
    if (this.imageLoadMode === 0) return true;
    if (this.imageLoadMode === 1) return this.netIsWifi;
    return this.forceLoaded;
  }

  build() {
    Stack() {
      if (!this.imgAllowed() && this.src.length > 0) {
        Column() {
          Text(this.imageLoadMode === 1 ? '仅WiFi' : '点击加载')
            .fontFamily(this.appFontFamily).fontSize(12)
            .fontColor(textTertiary(this.isDark))
        }
        .width('100%').height('100%')
        .backgroundColor(blendWithBg('#4477E0', 0.06, this.isDark, '#1E1E1E'))
        .borderRadius(this.imageBorderRadius)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.forceLoaded = true; })
      } else if (this.src.length > 0) {
        Image(this.src)
          .width(this.imageWidth)
          .height(this.imageHeight)
          .borderRadius(this.imageBorderRadius)
          .objectFit(this.objectFit)
          .onComplete(() => { this.loaded = true; })
          .onError(() => { this.failed = true; this.loaded = true; })
      }
      if (!this.loaded && !this.failed && this.imgAllowed() && this.src.length > 0) {
        LoadingProgress()
          .width(24).height(24)
          .color(textTertiary(this.isDark))
      }
      if (this.failed && this.imgAllowed()) {
        Column() {
          Text('加载失败')
            .fontFamily(this.appFontFamily).fontSize(12)
            .fontColor(textTertiary(this.isDark))
        }
        .width('100%').height('100%')
        .backgroundColor(pageBg(this.isDark))
        .borderRadius(this.imageBorderRadius)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width(typeof this.imageWidth === 'number' ? this.imageWidth : this.imageWidth)
    .height(typeof this.imageHeight === 'number' ? this.imageHeight : this.imageHeight)
  }
}