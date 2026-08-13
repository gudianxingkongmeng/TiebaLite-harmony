import router from '@ohos.router';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import promptAction from '@ohos.promptAction';
import http from '@ohos.net.http';
import fs from '@ohos.file.fs';
import pasteboard from '@ohos.pasteboard';
import common from '@ohos.app.ability.common';
import util from '@ohos.util';
import { systemShare } from '@kit.ShareKit';
import { fileUri } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { blendWithBg, pageBg, cardBg, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../../core/utils/DataHelper';
import MediaSaver from '../../core/utils/MediaSaver';
import { Dict } from '../../core/types/Dict';
import { setDarkStatusBar } from '../../core/utils/SystemBarHelper';
import ThreadImageFetcher from '../../core/utils/ThreadImageFetcher';

interface PicItem {
  url: string;
  overallIndex: number;
  picId: string;
}

@Entry
@Component
struct PhotoViewPage {
  @StorageLink('isDarkTheme') isDark: boolean = false;
  @StorageLink('showSwiperDots') showSwiperDots: boolean = true;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @State items: PicItem[] = [];
  @State currentIndex: number = 0;
  @State totalAmount: number = 0;
  @State totalKnown: boolean = false;
  @State hasNext: boolean = false;
  @State hasPrev: boolean = false;
  @State showActions: boolean = true;
  @State zoomScale: number = 1;
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  private _threadId: number = 0;
  private _forumId: number = 0;
  private _forumName: string = '';
  private _seed: string[] = [];
  private _loadingWindow: boolean = false;
  private _alive: boolean = true;
  private _sharePaths: Map<number, string> = new Map();

  aboutToAppear(): void {
    this._alive = true;
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      const urlsJson = params.urlsJson as string;
      if (urlsJson) {
        try {
          this._seed = JSON.parse(urlsJson) as string[];
        } catch (e) {
          this._seed = [];
        }
      } else {
        this._seed = (params.urls as string[]) || [];
      }
      this.currentIndex = (params.index as number) || 0;
      this._threadId = Number(params.threadId as string || '0');
      this._forumId = Number(params.forumId as string || '0');
      this._forumName = String(params.forumName || '');
      console.info('TiebaLite: [PHV] seed=' + this._seed.length + ' index=' + this.currentIndex + ' threadId=' + this._threadId);
    }
    this.items = this._seed.map((u: string, i: number) => {
      const it: PicItem = { url: u, overallIndex: i + 1, picId: ThreadImageFetcher.getPicIdFromUrl(u) };
      return it;
    });
    this.totalAmount = this.items.length;
    if (this.currentIndex >= this.items.length) this.currentIndex = Math.max(0, this.items.length - 1);
    void this.initWindow();
    this.ensureCurrentImageCached();
    void setDarkStatusBar(getContext(this));
  }

  private async initWindow(): Promise<void> {
    if (this._threadId <= 0 || this._loadingWindow) return;
    const anchor: PicItem = this.items[this.currentIndex];
    if (!anchor) return;
    this._loadingWindow = true;
    try {
      const info = await ThreadImageFetcher.fetchWindow(this._threadId, this._forumId, this._forumName, anchor.picId, anchor.overallIndex, false);
      if (!this._alive) return;
      if (info.amount > 0) {
        this.totalAmount = Math.max(info.amount, this.items.length);
        this.totalKnown = true;
        this.mergeWindow(info.items, false);
      }
    } finally {
      this._loadingWindow = false;
    }
  }

  private mergeWindow(windowItems: PicItem[], isPrev: boolean): void {
    if (windowItems.length === 0) return;
    const seen: Set<string> = new Set();
    for (const it of this.items) seen.add(it.picId);
    const add: PicItem[] = [];
    for (const w of windowItems) {
      if (!seen.has(w.picId)) {
        seen.add(w.picId);
        add.push(w);
      }
    }
    if (add.length === 0) return;
    if (isPrev) {
      this.items = add.concat(this.items);
      this.currentIndex += add.length;
    } else {
      this.items = this.items.concat(add);
    }
    this.recalcEdges();
    console.info('TiebaLite: [PHV] window ' + (isPrev ? 'prev' : 'next') + ' added=' + add.length + ' total=' + this.items.length);
  }

  private recalcEdges(): void {
    if (this.items.length === 0) return;
    const last = this.items[this.items.length - 1];
    const first = this.items[0];
    this.hasNext = last.overallIndex < this.totalAmount;
    this.hasPrev = first.overallIndex > 1;
  }

  private maybeLoadWindows(): void {
    if (this._loadingWindow) return;
    if (this.currentIndex >= this.items.length - 3 && this.hasNext) {
      void this.loadNextWindow();
    } else if (this.currentIndex <= 2 && this.hasPrev) {
      void this.loadPrevWindow();
    }
  }

  private async loadNextWindow(): Promise<void> {
    if (this._loadingWindow || !this.hasNext || this.items.length === 0) return;
    const anchor: PicItem = this.items[this.items.length - 1];
    this._loadingWindow = true;
    try {
      const info = await ThreadImageFetcher.fetchWindow(this._threadId, this._forumId, this._forumName, anchor.picId, anchor.overallIndex, false);
      if (!this._alive) return;
      if (info.amount > 0) {
        this.totalAmount = Math.max(info.amount, this.items.length);
        this.mergeWindow(info.items, false);
      }
    } finally {
      this._loadingWindow = false;
    }
  }

  private async loadPrevWindow(): Promise<void> {
    if (this._loadingWindow || !this.hasPrev || this.items.length === 0) return;
    const anchor: PicItem = this.items[0];
    this._loadingWindow = true;
    try {
      const info = await ThreadImageFetcher.fetchWindow(this._threadId, this._forumId, this._forumName, anchor.picId, anchor.overallIndex, true);
      if (!this._alive) return;
      if (info.amount > 0) {
        this.totalAmount = Math.max(info.amount, this.items.length);
        this.mergeWindow(info.items, true);
      }
    } finally {
      this._loadingWindow = false;
    }
  }

  onPageShow(): void {
    void setDarkStatusBar(getContext(this));
  }

  async downloadToFile(url: string, baseName: string): Promise<string> {
    if (!url) throw new Error('no url');
    try {
      const httpRequest = http.createHttp();
      const resp = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        header: { 'User-Agent': 'bdtb for Android 12.52.1.0', 'Referer': 'https://tieba.baidu.com/' }
      });
      httpRequest.destroy();
      if (resp.responseCode !== 200) throw new Error('http ' + resp.responseCode);
      const data = resp.result as ArrayBuffer;
      if (!data || data.byteLength === 0) throw new Error('empty response');
      let cleanUrl = url;
      const qIdx = cleanUrl.indexOf('?');
      if (qIdx >= 0) cleanUrl = cleanUrl.substring(0, qIdx);
      const lastDot = cleanUrl.lastIndexOf('.');
      const ext = lastDot >= 0 ? cleanUrl.substring(lastDot + 1).toLowerCase() : 'jpg';
      const dir = getContext(this).filesDir;
      const filePath = dir + '/' + baseName + '.' + ext;
      const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
      fs.writeSync(file.fd, data);
      fs.closeSync(file);
      return filePath;
    } catch (e) {
      throw new Error(String(e));
    }
  }

  private ensureCurrentImageCached(): void {
    const idx = this.currentIndex;
    const item = this.items[idx];
    if (!item || this._sharePaths.has(idx)) return;
    void this.cacheImageForShare(idx, item.url);
  }

  private async cacheImageForShare(idx: number, url: string): Promise<void> {
    try {
      const filePath = await this.downloadToFile(url, 'tieba_share_' + idx);
      this._sharePaths.set(idx, filePath);
      console.info('TiebaLite: [PHV] share cache ready idx=' + idx);
    } catch (e) {
      console.warn('TiebaLite: [PHV] share pre-cache fail idx=' + idx + ' ' + String(e));
    }
  }

  async saveCurrentImage(): Promise<void> {
    try {
      const item = this.items[this.currentIndex];
      if (!item) { promptAction.showToast({ message: '保存失败' }); return; }
      const url = item.url;
      const httpRequest = http.createHttp();
      const resp = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        header: { 'User-Agent': 'bdtb for Android 12.52.1.0', 'Referer': 'https://tieba.baidu.com/' }
      });
      httpRequest.destroy();
      const data = resp.result as ArrayBuffer;
      if (resp.responseCode !== 200 || !data || data.byteLength === 0) { promptAction.showToast({ message: '下载失败' }); return; }
      const head = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(data).slice(0, 64));
      if (head.indexOf('<html') >= 0 || head.indexOf('<!DOCTYPE') >= 0) { promptAction.showToast({ message: '下载失败' }); return; }
      let ext = 'jpg';
      const extMatch = url.match(/\.([a-zA-Z0-9]+)(\?.*)?$/);
      if (extMatch) {
        const rawExt = extMatch[1].toLowerCase();
        if (rawExt === 'jpg' || rawExt === 'jpeg' || rawExt === 'png' || rawExt === 'gif' || rawExt === 'webp' || rawExt === 'bmp') {
          ext = rawExt;
        }
      }
      await MediaSaver.saveToAlbum(getContext(this) as common.UIAbilityContext, data,
        photoAccessHelper.PhotoType.IMAGE, ext, 'tieba_' + Date.now());
      promptAction.showToast({ message: '已保存到相册 tieba lite' });
    } catch (e) {
      console.error('TiebaLite: saveImage error=' + String(e));
      promptAction.showToast({ message: (String(e).indexOf('canceled') >= 0) ? '已取消保存' : '保存失败' });
    }
  }

  async shareCurrentImage(): Promise<void> {
    try {
      const item = this.items[this.currentIndex];
      if (!item) { promptAction.showToast({ message: '分享失败' }); return; }
      const url = item.url;
      let filePath = this._sharePaths.get(this.currentIndex) || '';
      if (!filePath) {
        filePath = await this.downloadToFile(url, 'tieba_share_' + this.currentIndex);
        this._sharePaths.set(this.currentIndex, filePath);
      }
      try {
        const shareData: systemShare.SharedData = new systemShare.SharedData({
          utd: utd.UniformDataType.IMAGE,
          uri: fileUri.getUriFromPath(filePath),
          title: '图片分享'
        });
        const controller: systemShare.ShareController = new systemShare.ShareController(shareData);
        const context = getContext(this) as common.UIAbilityContext;
        await controller.show(context, {
          previewMode: systemShare.SharePreviewMode.DEFAULT,
          selectionMode: systemShare.SelectionMode.SINGLE
        });
      } catch (e) {
        const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, url);
        const pb = pasteboard.getSystemPasteboard();
        void pb.setData(data);
        promptAction.showToast({ message: '图片链接已复制到剪贴板', duration: 1500 });
      }
    } catch (e) {
      promptAction.showToast({ message: '分享失败' });
    }
  }

  aboutToDisappear(): void {
    this._alive = false;
    const keys = Array.from(this._sharePaths.keys());
    for (let i = 0; i < keys.length; i++) {
      const path = this._sharePaths.get(keys[i]);
      if (path) {
        try {
          fs.unlinkSync(path);
        } catch (e) {
          console.warn('TiebaLite: [PHV] cleanup fail ' + String(e));
        }
      }
    }
    this._sharePaths.clear();
  }

  isGifUrl(url: string): boolean {
    const u = url.toLowerCase();
    if (u.includes('.gif')) return true;
    if (u.includes('_gif') || u.includes('=gif') || u.includes('/gif')) return true;
    return false;
  }

  build() {
    Stack() {
      Swiper() {
        ForEach(this.items, (item: PicItem, index: number) => {
          Stack() {
            Image(item.url)
              .width('100%').height('100%')
              .objectFit(ImageFit.Contain)
              .onClick(() => { this.showActions = !this.showActions; })
              .gesture(
                PinchGesture({ distance: 1 })
                  .onActionUpdate((event: GestureEvent) => {
                    this.zoomScale = event.scale;
                  })
                  .onActionEnd(() => {
                    this.zoomScale = this.zoomScale < 1 ? 1 : this.zoomScale;
                  })
              )
            if (this.isGifUrl(item.url)) {
              Text('GIF').fontFamily(this.appFontFamily).fontSize(11).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
                .padding({ left: 5, right: 5, top: 2, bottom: 2 })
                .backgroundColor('#CC000000').borderRadius(4)
                .position({ top: 8, left: 8 })
            }
          }.width('100%').height('100%')
        })
      }
      .index(this.currentIndex)
      .loop(true)
      .indicator(this.showSwiperDots)
      .width('100%').height('100%')
      .backgroundColor('#000000')
      .onChange((idx: number) => {
        this.currentIndex = idx; this.zoomScale = 1; this.offsetX = 0; this.offsetY = 0;
        this.ensureCurrentImageCached();
        this.maybeLoadWindows();
      })

      Row() {
        Image($r('app.media.ic_arrow_back')).width(26).height(26).fillColor('#FFFFFF')
          .onClick(() => router.back())
        Blank()
        if (this.totalKnown) {
          Text(`${this.currentIndex + 1}/${this.totalAmount}`)
            .fontFamily(this.appFontFamily).fontSize(16).fontColor('#FFFFFF')
        }
      }
      .width('100%').padding(16).backgroundColor('#66000000')
      .position({ top: 0 })

      if (this.showActions) {
        Row() {
          Blank()
          Row() {
            Image($r('app.media.ic_download')).width(18).height(18).fillColor('#FFFFFF')
            Text('保存').fontFamily(this.appFontFamily).fontSize(16).fontColor('#FFFFFF').margin({ left: 4 })
          }
          .padding(16)
          .onClick(() => { this.saveCurrentImage(); })
          Row() {
            Image($r('app.media.ic_share')).width(18).height(18).fillColor('#FFFFFF')
            Text('分享').fontFamily(this.appFontFamily).fontSize(16).fontColor('#FFFFFF').margin({ left: 4 })
          }
          .padding(16).margin({ left: 8 })
          .onClick(() => { void this.shareCurrentImage(); })
        }
        .width('100%').backgroundColor('#66000000')
        .position({ bottom: 0 })
      }
    }
    .width('100%').height('100%').expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .scale({ x: this.zoomScale, y: this.zoomScale })
    
  }

  onBackPress(): boolean {
    NavigationHelper.markBack();
    return false;
  }

  pageTransition() {
    if (NavigationHelper.isFadeTransition()) {
      if (NavigationHelper.isBack) {
        PageTransitionEnter({ duration: 300, curve: Curve.FastOutSlowIn })
          .opacity(0)
        PageTransitionExit({ duration: 300, curve: Curve.FastOutSlowIn })
          .opacity(0)
          .scale({ x: 0.94, y: 0.94 })
      } else {
        PageTransitionEnter({ duration: 300, curve: Curve.FastOutSlowIn })
          .opacity(0)
          .scale({ x: 0.96, y: 0.96 })
        PageTransitionExit({ duration: 300, curve: Curve.FastOutSlowIn })
          .opacity(0)
          .scale({ x: 1.04, y: 1.04 })
      }
    } else if (NavigationHelper.isBack) {
      PageTransitionEnter({ duration: 350, curve: Curve.FastOutSlowIn })
        .slide(SlideEffect.Left)
      PageTransitionExit({ duration: 300, curve: Curve.FastOutSlowIn })
        .slide(SlideEffect.Right)
    } else {
      PageTransitionEnter({ duration: 350, curve: Curve.FastOutSlowIn })
        .slide(SlideEffect.Right)
      PageTransitionExit({ duration: 300, curve: Curve.FastOutSlowIn })
        .slide(SlideEffect.Left)
    }
  }
}

