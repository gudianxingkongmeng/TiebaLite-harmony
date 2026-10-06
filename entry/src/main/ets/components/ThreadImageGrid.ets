import router from '@ohos.router';
import { NavigationHelper } from '../core/utils/NavigationHelper';
import { Dict } from '../core/types/Dict';
import { getStr, getNum, blendWithWhite, darkenColor, blendWithBg, pageBg, cardBg, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../core/utils/DataHelper';
import VideoPlayer from './VideoPlayer';
import PreferencesManager from '../core/storage/PreferencesManager';
import NetworkUtil from '../core/utils/NetworkUtil';

@Component
export default struct ThreadImageGrid {
  @Prop @Watch('onMediaChange') urls: string[] = [];
  @Prop @Watch('onMediaChange') mediaItems: Dict[] = [];
  @StorageLink('isDarkTheme') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @StorageLink('videoListPip') listPipEnabled: boolean = false;
  @StorageLink('imageLoadMode') imageLoadMode: number = 0;
  @StorageLink('netIsWifi') netIsWifi: boolean = true;
  @State videoPos: number = 0;
  @State autoPlayMode: number = 0;
  @State isWifiNet: boolean = false;
  @State vUrl0: string = '';
  @State vPoster0: string = '';
  onOpenViewer?: (index: number) => void;

  onMediaChange(): void {
    this.vUrl0 = '';
    this.vPoster0 = '';
    if (this.mediaItems.length === 0) return;
    this.vUrl0 = this.getVideoUrl(0);
    this.vPoster0 = this.getVideoPoster(0);
    console.info('TiebaLite: [V7] grid video vUrl=' + this.vUrl0 + ' poster=' + this.vPoster0.substring(0, 50));
  }

  aboutToAppear(): void {
    this.vUrl0 = this.getVideoUrl(0);
    this.vPoster0 = this.getVideoPoster(0);
    console.info('TiebaLite: [V7a] grid aboutToAppear vUrl=' + this.vUrl0 + ' poster=' + this.vPoster0.substring(0, 50));
    PreferencesManager.getInstance().getInt('video_autoplay', 0).then((v: number) => {
      this.autoPlayMode = v;
    }).catch(() => {});
    NetworkUtil.isWifi().then((wifi: boolean) => {
      this.isWifiNet = wifi;
    }).catch(() => {});
  }

  private imgAllowed(): boolean {
    if (this.imageLoadMode === 0) return true;
    if (this.imageLoadMode === 1) return this.netIsWifi;
    return false;
  }

  private imgUrl(i: number): string {
    return this.imgAllowed() ? this.urls[i] : '';
  }

  private shouldAutoPlay(): boolean {
    if (this.autoPlayMode === 0) return true;
    if (this.autoPlayMode === 1) return this.isWifiNet;
    return false;
  }

  build() {
    if (this.urls.length > 0) {
    if (this.urls.length === 1) {
      Column() {
        Stack() {
          if (this.isVideoIndex(0)) {
            if (this.vUrl0) {
              VideoPlayer({
                videoUrl: this.vUrl0,
                posterUrl: this.vPoster0,
                autoPlay: this.shouldAutoPlay(),
                allowPip: this.listPipEnabled,
                loop: true,
                enableControls: true,
                videoWidth: '100%',
                videoHeight: '100%',
                videoBorderRadius: 8,
                onPositionChange: (sec: number) => { this.videoPos = sec; }
              })
            } else {
              Image(this.imgUrl(0))
                .width('100%').height('100%')
                .objectFit(this.singleImageFit())
                .borderRadius(8)
            }
          } else {
            Image(this.imgUrl(0))
              .width('100%').height('100%')
              .objectFit(this.singleImageFit())
              .borderRadius(8)
          }
          if (this.isGifIndex(0)) {
            Text('GIF').fontFamily(this.appFontFamily).fontSize(10).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .backgroundColor('#CC000000').borderRadius(3)
              .position({ top: 4, left: 4 })
          }
          if (this.isVideoIndex(0)) {
            Text(this.getVideoDuration(0)).fontFamily(this.appFontFamily).fontSize(11).fontColor('#FFFFFF')
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .backgroundColor('#CC000000').borderRadius(3)
              .position({ bottom: 4, right: 4 })
          }
        }
      }
      .width('100%').height(190).clip(true).margin({ top: 8 })
      .onClick(() => { if (!this.isVideoIndex(0)) this.notifyOpen(0); })
    } else if (this.urls.length === 2) {
      Row() {
        Stack() {
          Image(this.imgUrl(0)).width('100%').height('100%').objectFit(ImageFit.Contain)
          if (this.isGifIndex(0)) {
            Text('GIF').fontFamily(this.appFontFamily).fontSize(10).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .backgroundColor('#CC000000').borderRadius(3)
              .position({ top: 4, left: 4 })
          }
          if (this.isVideoIndex(0)) {
            Column() {
              Text('▶').fontFamily(this.appFontFamily).fontSize(20).fontColor('#FFFFFF')
            }
            .width('100%').height('100%')
            .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
            Text(this.getVideoDuration(0)).fontFamily(this.appFontFamily).fontSize(10).fontColor('#FFFFFF')
              .padding({ left: 3, right: 3, top: 1, bottom: 1 })
              .backgroundColor('#CC000000').borderRadius(3)
              .position({ bottom: 3, right: 3 })
          }
        }
        .borderRadius(8).clip(true).margin({ right: 2 })
        .layoutWeight(1).aspectRatio(this.getAspectRatio(0))
        .constraintSize({ maxHeight: 280 })
        .onClick(() => this.notifyOpen(0))
        Stack() {
          Image(this.imgUrl(1)).width('100%').height('100%').objectFit(ImageFit.Contain)
          if (this.isGifIndex(1)) {
            Text('GIF').fontFamily(this.appFontFamily).fontSize(10).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .backgroundColor('#CC000000').borderRadius(3)
              .position({ top: 4, left: 4 })
          }
          if (this.isVideoIndex(1)) {
            Column() {
              Text('▶').fontFamily(this.appFontFamily).fontSize(20).fontColor('#FFFFFF')
            }
            .width('100%').height('100%')
            .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
            Text(this.getVideoDuration(1)).fontFamily(this.appFontFamily).fontSize(10).fontColor('#FFFFFF')
              .padding({ left: 3, right: 3, top: 1, bottom: 1 })
              .backgroundColor('#CC000000').borderRadius(3)
              .position({ bottom: 3, right: 3 })
          }
        }
        .borderRadius(8).clip(true).margin({ left: 2 })
        .layoutWeight(1).aspectRatio(this.getAspectRatio(1))
        .constraintSize({ maxHeight: 280 })
        .onClick(() => this.notifyOpen(1))
      }
      .width('100%').margin({ top: 8 })
    } else {
      Row() {
        Stack() {
          Image(this.imgUrl(0)).width('100%').height('100%').objectFit(ImageFit.Cover)
          if (this.isGifIndex(0)) {
            Text('GIF').fontFamily(this.appFontFamily).fontSize(10).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .backgroundColor('#CC000000').borderRadius(3)
              .position({ top: 4, left: 4 })
          }
          if (this.isVideoIndex(0)) {
            Column() {
              Text('▶').fontFamily(this.appFontFamily).fontSize(24).fontColor('#FFFFFF')
            }
            .width('100%').height('100%')
            .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
            Text(this.getVideoDuration(0)).fontFamily(this.appFontFamily).fontSize(11).fontColor('#FFFFFF')
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .backgroundColor('#CC000000').borderRadius(3)
              .position({ bottom: 4, right: 4 })
          }
        }
        .borderRadius(8).clip(true).margin({ right: 2 })
        .layoutWeight(2).height('100%')
        .onClick(() => this.notifyOpen(0))
        Column() {
          Stack() {
            Image(this.imgUrl(1)).width('100%').height('100%').objectFit(ImageFit.Cover)
            if (this.isGifIndex(1)) {
              Text('GIF').fontFamily(this.appFontFamily).fontSize(10).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
                .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                .backgroundColor('#CC000000').borderRadius(3)
                .position({ top: 4, left: 4 })
            }
            if (this.isVideoIndex(1)) {
              Column() {
                Text('▶').fontFamily(this.appFontFamily).fontSize(16).fontColor('#FFFFFF')
              }
              .width('100%').height('100%')
              .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
              Text(this.getVideoDuration(1)).fontFamily(this.appFontFamily).fontSize(10).fontColor('#FFFFFF')
                .padding({ left: 3, right: 3, top: 1, bottom: 1 })
                .backgroundColor('#CC000000').borderRadius(3)
                .position({ bottom: 3, right: 3 })
            }
          }
          .borderRadius(8).clip(true).margin({ bottom: 2 })
          .layoutWeight(1).width('100%')
          .onClick(() => this.notifyOpen(1))
          Stack() {
            Image(this.imgUrl(2)).width('100%').height('100%').objectFit(ImageFit.Cover)
            if (this.urls.length > 3) {
              Text('+' + (this.urls.length - 3))
                .fontFamily(this.appFontFamily).fontSize(12).fontColor('#FFFFFF')
                .backgroundColor('#CC000000')
                .borderRadius(10)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .position({ bottom: 4, right: 4 })
            }
            if (this.isGifIndex(2)) {
              Text('GIF').fontFamily(this.appFontFamily).fontSize(10).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
                .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                .backgroundColor('#CC000000').borderRadius(3)
                .position({ top: 4, left: 4 })
            }
            if (this.isVideoIndex(2)) {
              Column() {
                Text('▶').fontFamily(this.appFontFamily).fontSize(16).fontColor('#FFFFFF')
              }
              .width('100%').height('100%')
              .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
              Text(this.getVideoDuration(2)).fontFamily(this.appFontFamily).fontSize(10).fontColor('#FFFFFF')
                .padding({ left: 3, right: 3, top: 1, bottom: 1 })
                .backgroundColor('#CC000000').borderRadius(3)
                .position({ bottom: 3, right: 3 })
            }
          }
          .borderRadius(8).clip(true).margin({ top: 2 })
          .layoutWeight(1).width('100%')
          .onClick(() => this.notifyOpen(2))
        }
        .layoutWeight(1).height('100%')
      }
      .width('100%')
      .height(190)
      .margin({ top: 8 })
    }
    }
  }

  private isGifIndex(idx: number): boolean {
    if (idx < this.urls.length && this.urls[idx].toLowerCase().includes('.gif')) return true;
    if (idx < this.mediaItems.length) {
      const m = this.mediaItems[idx];
      if (m.is_gif === 1 || m.gif === 1) return true;
      if (String(m.media_type || '').toLowerCase() === 'gif') return true;
      if (String(m.src || '').toLowerCase().includes('.gif')) return true;
    }
    return false;
  }

private isVideoIndex(idx: number): boolean {
    if (idx >= this.mediaItems.length) return false;
    const m = this.mediaItems[idx];
    if (m.is_video === 1 || m.isVideo === 1 || m.type === 5 || String(m.type) === 'flash') return true;
    if (String(m.media_type || '').toLowerCase() === 'video') return true;
    const urlHint = getStr(m, 'vhsrc', 'vsrc', 'video_url', 'videoUrl', 'url', 'link', 'src', 'thumbnailUrl', 'thumbnail');
    if (urlHint) {
      const lower: string = urlHint.toLowerCase();
      if (lower.includes('.mp4') || lower.includes('.webm') || lower.includes('.m3u8') ||
          lower.includes('/video/') || lower.includes('vbdsrc') || lower.includes('vd.bdstatic')) {
        return true;
      }
    }
    return false;
  }

private getVideoUrl(idx: number): string {
    if (idx >= this.mediaItems.length) return '';
    const m = this.mediaItems[idx];
    const candidates: string[] = [
      getStr(m, 'vhsrc'),
      getStr(m, 'vsrc'),
      getStr(m, 'origin_video_url', 'originVideoUrl'),
      getStr(m, 'video_url', 'videoUrl'),
      getStr(m, 'hevc_url', 'hevcUrl'),
      getStr(m, 'sd_video_url', 'hd_video_url', 'video_src', 'videoSrc'),
      getStr(m, 'url'),
      getStr(m, 'play_url', 'playUrl'),
      getStr(m, 'mediaUrl', 'media_url'),
      getStr(m, 'link'),
      getStr(m, 'src', 'origin_src'),
      getStr(m, 'thumbnailUrl', 'thumbnail')
    ];
    const videoExts: string[] = ['.mp4', '.webm', '.3gp', '.mov', '.avi', '.m3u8'];
    for (const url of candidates) {
      if (!url) continue;
      const lower: string = url.toLowerCase();
      if (videoExts.some((e: string) => lower.includes(e)) ||
          lower.includes('/video/') ||
          lower.includes('vbdsrc') ||
          lower.includes('vd.bdstatic')) {
        const result = url.startsWith('http://') ? 'https://' + url.substring(7) : url;
        console.info('TiebaLite: videoUrl=' + result);
        return result;
      }
    }
    return '';
  }

  private getVideoPoster(idx: number): string {
    if (idx >= this.mediaItems.length || idx >= this.urls.length) return '';
    const m = this.mediaItems[idx];
    const poster: string = getStr(m, 'bsrc', 'vpic', 'poster', 'posterUrl', 'cover', 'coverUrl', 'thumbnail', 'thumbnailUrl', 'photo', 'pic_url', 'picUrl');
    if (poster) {
      const lower: string = poster.toLowerCase();
      if (!lower.endsWith('.mp4') && !lower.endsWith('.webm') && !lower.endsWith('.m3u8')) {
        return poster;
      }
    }
    const first = this.urls[idx];
    if (first && !first.toLowerCase().endsWith('.mp4') && !first.toLowerCase().endsWith('.webm') && !first.toLowerCase().endsWith('.m3u8')) {
      return first;
    }
    return '';
  }

  private getVideoDuration(idx: number): string {
    if (idx >= this.mediaItems.length) return '';
    const d = String(this.mediaItems[idx].during_time || this.mediaItems[idx].duration || this.mediaItems[idx].duringTime || '');
    if (!d) return '';
    const secs = parseInt(d);
    if (isNaN(secs) || secs <= 0) return '';
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return m > 0 ? m + ':' + (s < 10 ? '0' : '') + s : '0:' + (s < 10 ? '0' : '') + s;
  }

  private getAspectRatio(idx: number): number {
    if (idx < this.mediaItems.length) {
      const w = getNum(this.mediaItems[idx], 'width', 'originWidth', 'origin_width', 'bigWidth', 'big_width');
      const h = getNum(this.mediaItems[idx], 'height', 'originHeight', 'origin_height', 'bigHeight', 'big_height');
      if (w > 0 && h > 0) return w / h;
    }
    return 1;
  }

  private singleImageFit(): ImageFit {
    if (this.mediaItems.length > 0) {
      const w = getNum(this.mediaItems[0], 'width', 'originWidth', 'origin_width', 'bigWidth', 'big_width');
      const h = getNum(this.mediaItems[0], 'height', 'originHeight', 'origin_height', 'bigHeight', 'big_height');
      if (w > 0 && h > 0 && h / w <= 1.78) {
        return ImageFit.Contain;
      }
    }
    return ImageFit.Cover;
  }

  private notifyOpen(index: number): void {
    if (this.onOpenViewer) {
      this.onOpenViewer(index);
    } else {
      this.openViewer(index);
    }
  }

  private openViewer(index: number) {
    if (this.isVideoIndex(index)) {
      const vUrl = this.getVideoUrl(index);
      if (vUrl) {
        NavigationHelper.navigate('pages/videoview/VideoViewPage', { videoUrl: vUrl, posterUrl: this.urls[index] || '', startPosition: this.videoPos, videoAspect: this.getAspectRatio(index), videoDuration: Number(this.mediaItems[index].during_time || this.mediaItems[index].duration || this.mediaItems[index].duringTime || 0) || 0 });
        return;
      }
    }
    NavigationHelper.navigate('pages/photoview/PhotoViewPage', { urls: this.urls, index: index });
  }
}
