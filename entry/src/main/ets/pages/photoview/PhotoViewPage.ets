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
import { TopInsetHelper } from '../../core/utils/TopInsetHelper';
import ThreadImageFetcher from '../../core/utils/ThreadImageFetcher';

interface PicItem {
  url: string;
  overallIndex: number;
  picId: string;
}

/** Image.onComplete 回传的原始图片信息（SDK 里是内联对象，这里用接口复刻） */
interface ImageCompleteInfo {
  width?: number;
  height?: number;
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
  // 计数分母：已知总数时用真实总数，否则退回已加载数量，保证「x/y」始终可见。
  // 用 @State 而非 getter：ArkUI 不会追踪 getter 内部依赖的字段变化。
  @State displayTotal: number = 1;
  // 全屏沉浸式布局下需自行避让状态栏与手势条
  @State topInset: number = 0;
  @State bottomInset: number = 0;
  @State hasNext: boolean = false;
  @State hasPrev: boolean = false;
  @State showActions: boolean = true;
  @State zoomScale: number = 1;
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  // 当前图片的原始像素尺寸，用于计算放大后可平移的范围
  @State curImgW: number = 0;
  @State curImgH: number = 0;
  // 可视区域尺寸（objectFit(Contain) 下的基准容器尺寸）
  @State viewW: number = 0;
  @State viewH: number = 0;
  private _panStartX: number = 0;
  private _panStartY: number = 0;
  private _fingerStartX: number = 0;
  private _fingerStartY: number = 0;
  private _pinchBaseScale: number = 1;
  private _threadId: number = 0;
  private _forumId: number = 0;
  private _forumName: string = '';
  private _seed: string[] = [];
  private _loadingWindow: boolean = false;
  private _alive: boolean = true;
  private _sharePaths: Map<number, string> = new Map();

  aboutToAppear(): void {
    this._alive = true;
    this.loadInsets();
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
    this.syncDisplayTotal();
    void this.initWindow();
    this.ensureCurrentImageCached();
    void setDarkStatusBar(getContext(this));
  }

  /** 同步计数分母：已知总数用真实值，否则退回已加载数量 */
  private syncDisplayTotal(): void {
    if (this.totalKnown) {
      this.displayTotal = Math.max(this.totalAmount, this.items.length);
    } else {
      this.displayTotal = Math.max(this.items.length, 1);
    }
  }

  /** 读取状态栏与手势区高度，避免顶部计数与系统图标重叠 */
  private loadInsets(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    TopInsetHelper.get(ctx).then((top: number) => { this.topInset = top; }).catch(() => {});
    TopInsetHelper.getBottom(ctx).then((bottom: number) => { this.bottomInset = bottom; }).catch(() => {});
  }

  private async initWindow(): Promise<void> {
    if (this._threadId <= 0 || this._loadingWindow) return;
    const anchor: PicItem = this.items[this.currentIndex];
    if (!anchor) return;
    this._loadingWindow = true;
    try {
      const info = await ThreadImageFetcher.fetchWindow(this._threadId, this._forumId, this._forumName, anchor.picId, anchor.overallIndex, false);
      if (!this._alive || !info) return;
      if (info.amount > 0) {
        this.totalAmount = Math.max(info.amount, this.items.length);
        this.totalKnown = true;
        this.syncDisplayTotal();
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
    if (this.totalKnown) {
      this.totalAmount = Math.max(this.totalAmount, this.items.length);
    }
    this.syncDisplayTotal();
    this.recalcEdges();
    console.info('TiebaLite: [PHV] window ' + (isPrev ? 'prev' : 'next') + ' added=' + add.length + ' total=' + this.items.length);
  }

  private recalcEdges(): void {
    if (this.items.length === 0) return;
    const last = this.items[this.items.length - 1];
    const first = this.items[0];
    // 总数未知时（totalKnown=false）不能据此判定没有下一页，
    // 否则首次进入时会因为 totalAmount 初始等于 items.length 而停止加载后续窗口。
    if (this.totalKnown) {
      this.hasNext = last.overallIndex < this.totalAmount;
    } else {
      this.hasNext = true;
    }
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
      if (!this._alive || !info) return;
      if (info.amount > 0) {
        this.totalAmount = Math.max(info.amount, this.items.length);
        this.totalKnown = true;
        this.syncDisplayTotal();
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
      if (!this._alive || !info) return;
      if (info.amount > 0) {
        this.totalAmount = Math.max(info.amount, this.items.length);
        this.totalKnown = true;
        this.syncDisplayTotal();
        this.mergeWindow(info.items, true);
      }
    } finally {
      this._loadingWindow = false;
    }
  }

  onPageShow(): void {
    void setDarkStatusBar(getContext(this));
    this.loadInsets();
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

  /**
   * 图片在 objectFit(Contain) 下的实际绘制尺寸。
   * 缩放后可平移的范围由它决定：绘制尺寸超出容器的部分，就是边缘之外多出来的余量。
   */
  private contentSize(): number[] {
    const iw = this.curImgW;
    const ih = this.curImgH;
    const vw = this.viewW;
    const vh = this.viewH;
    if (iw <= 0 || ih <= 0 || vw <= 0 || vh <= 0) return [vw, vh];
    const fit = Math.min(vw / iw, vh / ih);
    return [iw * fit, ih * fit];
  }

  /** 横向最大平移距离：放大后图片超出容器宽度的部分的一半 */
  private maxOffsetX(): number {
    if (this.viewW <= 0) return 0;
    return Math.max(0, (this.contentSize()[0] * this.zoomScale - this.viewW) / 2);
  }

  /** 纵向最大平移距离 */
  private maxOffsetY(): number {
    if (this.viewH <= 0) return 0;
    return Math.max(0, (this.contentSize()[1] * this.zoomScale - this.viewH) / 2);
  }

  /** 把平移量夹在图片边缘内，不允许拖出图片外 */
  private clampOffsets(): void {
    const mx = this.maxOffsetX();
    const my = this.maxOffsetY();
    const nx = Math.max(-mx, Math.min(mx, this.offsetX));
    const ny = Math.max(-my, Math.min(my, this.offsetY));
    if (nx !== this.offsetX) this.offsetX = nx;
    if (ny !== this.offsetY) this.offsetY = ny;
  }

  /** 复位缩放与位移（切图、缩回 1 倍时用） */
  private resetZoom(): void {
    this.zoomScale = 1;
    this.offsetX = 0;
    this.offsetY = 0;
    this._pinchBaseScale = 1;
  }

  private get isZoomed(): boolean {
    return this.zoomScale > 1.001;
  }

  /** 双击放大的目标倍数 */
  private static readonly DBL_TAP_SCALE: number = 2.5;
  private _lastTapTime: number = 0;
  private _lastTapX: number = 0;
  private _lastTapY: number = 0;

  /**
   * 以点击点为中心缩放 / 还原。
   * onClick 的 event.x/y 是组件内坐标；组件铺满容器且图片 Contain 居中，
   * 所以组件中心即图片中心。要让被点中的像素缩放后不动，可得 offset = t * (1 - s)。
   */
  private toggleZoomAt(localX: number, localY: number): void {
    if (this.isZoomed) {
      this.resetZoom();
      return;
    }
    if (localX > 0 && localY > 0 && this.viewW > 0 && this.viewH > 0) {
      const tx = localX - this.viewW / 2;
      const ty = localY - this.viewH / 2;
      this.zoomScale = PhotoViewPage.DBL_TAP_SCALE;
      this.offsetX = tx * (1 - PhotoViewPage.DBL_TAP_SCALE);
      this.offsetY = ty * (1 - PhotoViewPage.DBL_TAP_SCALE);
      this.clampOffsets();
    } else {
      // 拿不到点击位置时退化为居中放大
      this.zoomScale = PhotoViewPage.DBL_TAP_SCALE;
      this.clampOffsets();
    }
  }

  /** 放大态覆盖层要显示的当前图片 */
  private currentUrl(): string {
    if (this.currentIndex >= 0 && this.currentIndex < this.items.length) {
      return this.items[this.currentIndex].url;
    }
    return '';
  }

  build() {
    Stack() {
      // 始终渲染同一棵树。
      // 之前用 isZoomed 做条件切换，把 Swiper 和独立容器互斥，
      // 结果 scale 越过 1 的瞬间正在执行的 Pinch 手势所在组件被销毁，手势中断。
      // 现在靠 priorityGesture 让平移优先于 Swiper，用 disableSwipe 停掉翻页，
      // 组件树不发生切换，手势才能连续执行。
      Swiper() {
        ForEach(this.items, (item: PicItem, index: number) => {
          Stack() {
            Image(item.url)
              .width('100%').height('100%')
              .objectFit(ImageFit.Contain)
              .onComplete((event?: ImageCompleteInfo): void => {
                // 记录原始像素尺寸，放大后据此限制平移范围
                if (index === this.currentIndex && event) {
                  if (event.width && event.width > 0) this.curImgW = event.width;
                  if (event.height && event.height > 0) this.curImgH = event.height;
                }
              })
              // 单击切换操作栏；300ms 内的第二次点击视为双击，切换缩放。
              // 刻意复用已有的 onClick，而不是新增 TapGesture —— 之前反复尝试过
              // count:2 / 单击手势 / priorityGesture，都会和 Swiper 抢手势，
              // 结果连原有的捏合和平移也一起失效。onClick 已经能稳定收到点击。
              .onClick((event: ClickEvent): void => {
                const now = Date.now();
                const cx = Number(event.x || 0);
                const cy = Number(event.y || 0);
                // 两次点击位置接近才算双击，避免滑动中的误触
                if (now - this._lastTapTime <= 300 &&
                  Math.abs(cx - this._lastTapX) < 60 && Math.abs(cy - this._lastTapY) < 60) {
                  this._lastTapTime = 0;
                  this.toggleZoomAt(cx, cy);
                  return;
                }
                this._lastTapTime = now;
                this._lastTapX = cx;
                this._lastTapY = cy;
                this.showActions = !this.showActions;
              })
              .translate({ x: this.offsetX, y: this.offsetY })
              // 列表态只负责「起手缩放」：双指与 Swiper 的单指横滑不冲突。
              // 单指平移不能挂在这里，否则会被 Swiper 抢走。
              // 平移由下面的覆盖层在放大后独占处理。
              .gesture(
                PinchGesture({ distance: 1 })
                  .onActionStart((): void => { this._pinchBaseScale = this.zoomScale; })
                  .onActionUpdate((event: GestureEvent): void => {
                    this.zoomScale = Math.max(1, Math.min(5, this._pinchBaseScale * event.scale));
                    this.clampOffsets();
                  })
                  .onActionEnd((): void => {
                    if (this.zoomScale <= 1.001) { this.resetZoom(); } else { this.clampOffsets(); }
                  })
              )
            if (this.isGifUrl(item.url)) {
              Text('GIF').fontFamily(this.appFontFamily).fontSize(11).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
                .padding({ left: 5, right: 5, top: 2, bottom: 2 })
                .backgroundColor('#CC000000').borderRadius(4)
                .position({ top: 8, left: 8 })
            }
          }
          .width('100%').height('100%')
          .onAreaChange((_old: Area, newArea: Area): void => {
            const w = newArea.width as number;
            const h = newArea.height as number;
            if (w > 0 && Math.abs(w - this.viewW) > 0.5) this.viewW = w;
            if (h > 0 && Math.abs(h - this.viewH) > 0.5) this.viewH = h;
          })
        })
      }
      .index(this.currentIndex)
      .loop(true)
      .indicator(this.showSwiperDots)
      .width('100%').height('100%')
      .backgroundColor('#000000')
      // 放大后停掉翻页，避免拖动看图时误触发切图；缩回 1 倍自动恢复
      .disableSwipe(this.isZoomed)
      .onChange((idx: number): void => {
        this.currentIndex = idx;
        this.resetZoom();
        this.curImgW = 0;
        this.curImgH = 0;
        this.ensureCurrentImageCached();
        this.maybeLoadWindows();
      })

      // 放大态覆盖层：常驻组件树，只切换 visibility。
      // 之前三种做法都失败过——条件渲染会销毁承载手势的组件；
      // priorityGesture + disableSwipe 仍抢不过 Swiper 的横滑；
      // hitTestBehavior 只能让图片"看起来"接管，Swiper 仍握着触摸。
      // 覆盖层可见时位于 Swiper 之上，触摸根本到不了 Swiper，才算真正独占。
      // 用 Hidden 而非不渲染，保证捏合起始后组件不会被销毁、手势不中断。
      Stack() {
        Image(this.currentUrl())
          .width('100%').height('100%')
          .objectFit(ImageFit.Contain)
          .scale({ x: this.zoomScale, y: this.zoomScale })
          .translate({ x: this.offsetX, y: this.offsetY })
          .gesture(
            // 用手指的全局坐标而不是 event.offsetX 算位移。
            // 图片被 scale 放大后，组件局部坐标被压缩了 1/zoomScale，
            // 而 .translate() 走的是父级坐标，直接用 offsetX 会让图片
            // 移动距离明显小于手指行程（放大倍数越高越明显）。
            // globalX/globalY 是屏幕绝对坐标，不受组件变换影响，1:1 跟手。
            PanGesture({ fingers: 1, direction: PanDirection.All })
              .onActionStart((event: GestureEvent): void => {
                this._panStartX = this.offsetX;
                this._panStartY = this.offsetY;
                const fl = event.fingerList;
                if (fl && fl.length > 0) {
                  this._fingerStartX = fl[0].globalX;
                  this._fingerStartY = fl[0].globalY;
                }
              })
              .onActionUpdate((event: GestureEvent): void => {
                const fl = event.fingerList;
                if (!fl || fl.length === 0) return;
                const dx = fl[0].globalX - this._fingerStartX;
                const dy = fl[0].globalY - this._fingerStartY;
                this.offsetX = this._panStartX + dx;
                this.offsetY = this._panStartY + dy;
                this.clampOffsets();
              })
          )
          .gesture(
            // 放大后继续捏合可以缩放/还原，起点从当前缩放值累积
            PinchGesture({ distance: 1 })
              .onActionStart((): void => { this._pinchBaseScale = this.zoomScale; })
              .onActionUpdate((event: GestureEvent): void => {
                this.zoomScale = Math.max(1, Math.min(5, this._pinchBaseScale * event.scale));
                this.clampOffsets();
              })
              .onActionEnd((): void => {
                if (this.zoomScale <= 1.001) { this.resetZoom(); } else { this.clampOffsets(); }
              })
          )
              .onClick((event: ClickEvent): void => {
                const now = Date.now();
                const cx = Number(event.x || 0);
                const cy = Number(event.y || 0);
                if (now - this._lastTapTime <= 300 &&
                  Math.abs(cx - this._lastTapX) < 60 && Math.abs(cy - this._lastTapY) < 60) {
                  this._lastTapTime = 0;
                  this.toggleZoomAt(cx, cy);
                  return;
                }
                this._lastTapTime = now;
                this._lastTapX = cx;
                this._lastTapY = cy;
                this.showActions = !this.showActions;
              })
      }
      .width('100%').height('100%')
      .backgroundColor('#000000')
      // 不能用 Visibility.Hidden：隐藏状态下 Image 不会加载图片，
      // 一旦显示就是空白，反而把下面能正常缩放的图片盖住，表现为"放不大"。
      // opacity(0) 仍然会渲染并完成图片加载，只是看不见；
      // 触摸用 hitTestBehavior 单独控制，未放大时穿透给 Swiper。
      .opacity(this.isZoomed ? 1 : 0)
      .hitTestBehavior(this.isZoomed ? HitTestMode.Default : HitTestMode.None)
      .onAreaChange((_old: Area, newArea: Area): void => {
        const w = newArea.width as number;
        const h = newArea.height as number;
        if (w > 0 && Math.abs(w - this.viewW) > 0.5) this.viewW = w;
        if (h > 0 && Math.abs(h - this.viewH) > 0.5) this.viewH = h;
      })

      Row() {
        Image($r('app.media.ic_arrow_back')).width(26).height(26).fillColor('#FFFFFF')
          .onClick(() => router.back())
        Blank()
        if (this.items.length > 0) {
          // totalKnown 为 false（picPage 未返回总数）时，至少显示已加载数量，
          // 避免计数整块消失让用户以为功能坏了
          Text(`${this.currentIndex + 1}/${this.displayTotal}`)
            .fontFamily(this.appFontFamily).fontSize(16).fontColor('#FFFFFF')
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16 + this.topInset, bottom: 16 })
      .backgroundColor('#66000000')
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
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 16 + this.bottomInset })
        .backgroundColor('#66000000')
        .position({ bottom: 0 })
      }
    }
    .width('100%').height('100%').expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    // 缩放只作用于图片本身，这里不能再加 scale，
    // 否则顶栏、指示器和整层容器会跟着一起缩放。
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

