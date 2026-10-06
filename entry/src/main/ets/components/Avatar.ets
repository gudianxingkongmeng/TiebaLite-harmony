import { blendWithWhite, darkenColor, blendWithBg, pageBg, cardBg, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../core/utils/DataHelper';

@Component
export default struct Avatar {
  @Prop portrait: string = '';
  @Prop avatarSize: number = 40;
  @Prop defaultName: string = '';
  @StorageLink('isDarkTheme') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @StorageLink('imageLoadMode') imageLoadMode: number = 0;
  @StorageLink('netIsWifi') netIsWifi: boolean = true;
  @State imageFailed: boolean = false;

  private imgAllowed(): boolean {
    if (this.imageLoadMode === 0) return true;
    if (this.imageLoadMode === 1) return this.netIsWifi;
    return false;
  }

  build() {
    Stack() {
      if (this.portrait.length > 0 && !this.imageFailed && this.imgAllowed()) {
        Image(this.portrait)
          .width(this.avatarSize)
          .height(this.avatarSize)
          .borderRadius(this.avatarSize / 2)
          .objectFit(ImageFit.Cover)
          .onError(() => { this.imageFailed = true; })
      } else if (this.defaultName.length > 0) {
        Circle()
          .width(this.avatarSize)
          .height(this.avatarSize)
          .fill('#E0E0E0')
        Text(this.defaultName.substring(0, 1))
          .fontFamily(this.appFontFamily).fontSize(this.avatarSize * 0.4)
          .fontColor(textSecondary(this.isDark))
      } else {
        Circle()
          .width(this.avatarSize)
          .height(this.avatarSize)
          .fill('#E0E0E0')
      }
    }
  }
}
