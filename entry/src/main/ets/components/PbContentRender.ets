import { Dict } from '../core/types/Dict';
import { textPrimary, textSecondary, pageBg, cardBg, blendWithBg } from '../core/utils/DataHelper';
import EmojiImage from './EmojiImage';
import { registerEmoji, getEmojiIdFromMap, isInlineEmojiType, resolveEmojiId as resolveEmojiIdFromMgr, isEmojiText } from './EmojiManager';
import { PhotoUrlCache } from '../core/utils/ThreadImageFetcher';
import PreferencesManager from '../core/storage/PreferencesManager';
import NetworkUtil from '../core/utils/NetworkUtil';
import VideoPlayer from './VideoPlayer';
import common from '@ohos.app.ability.common';

interface ContentGroup {
  isInline: boolean;
  items: Dict[];
  origIndices: number[];
}

interface UrlSeg {
  text: string;
  isUrl: boolean;
}

@Component
export default struct PbContentRender {
  @StorageLink('fontScale') fontScale: number = 1.06;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @StorageLink('isDarkTheme') isDark: boolean = false;
  @StorageLink('imageLoadMode') imageLoadMode: number = 0;
  @StorageLink('netIsWifi') netIsWifi: boolean = true;
  @Prop @Watch('onContentsChange') contents: Dict[] = [];
  @Prop allImageUrls: string[] = [];
  @Prop allImageStartIndex: number = 0;
  @Prop threadId: number = 0;
  @Prop forumId: number = 0;
  @Prop forumName: string = '';
  @State autoPlayMode: number = 0;
  @State isWifiNet: boolean = false;
  @State videoCurrentSec: number = 0;
  @State firstVideoUrl: string = '';
  @State firstVideoPoster: string = '';
  private _pbLogged: boolean = false;

  onContentsChange(): void {
    console.info('TiebaLite: [V5] contents change, items=' + this.contents.length);
    this.refreshFirstVideo();
  }

  private refreshFirstVideo(): void {
    const groups = this.buildGroups();
    for (let i = 0; i < groups.length; i++) {
      const items = groups[i].items;
      if (items.length > 0 && Number(items[0].type) === 5) {
        const url = this.resolveVideoUrl(items[0]);
        const poster = this.toHttps(String(items[0].bsrc || items[0].src || ''));
        this.firstVideoUrl = url;
        this.firstVideoPoster = poster;
        console.info('TiebaLite: [V6] firstVideo url=' + url + ' poster=' + poster.substring(0, 60) + ' itemText=' + String(items[0].text || '').substring(0, 60));
        return;
      }
    }
    this.firstVideoUrl = '';
    this.firstVideoPoster = '';
  }

  aboutToAppear(): void {
    PreferencesManager.getInstance().getInt('video_autoplay', 0).then((v: number) => {
      this.autoPlayMode = v;
    }).catch(() => {});
    NetworkUtil.isWifi().then((wifi: boolean) => {
      this.isWifiNet = wifi;
    }).catch(() => {});
    if (Array.isArray(this.contents) && this.contents.length > 0) {
      console.info('TiebaLite: [V5b] aboutToAppear init, items=' + this.contents.length);
      this.refreshFirstVideo();
    }
  }

  private isInlineType(t: number): boolean {
    return t === 0 || t === 2 || t === 4 || t === 6 || t === 7 || t === 9 || t === 10 || t === 11 || t === 12 || t === 13 || t === 18 || t === 40;
  }

  private splitUrlText(text: string): UrlSeg[] {
    const out: UrlSeg[] = [];
    if (!text) return out;
    const cleaned = text.replace(/\r\n/g, ' ').replace(/[\r\n]/g, ' ').replace(/\s+/g, ' ').trim();
    const re = /(https?:\/\/[^\s\u4e00-\u9fff]+)/g;
    const trail: string = '。，、；：！？…()（）[]【】{}"\'';
    let last = 0;
    let m: RegExpExecArray | null = null;
    while ((m = re.exec(cleaned)) !== null) {
      if (m.index > last) out.push({ text: cleaned.substring(last, m.index), isUrl: false });
      let u = m[0];
      while (u.length > 1 && trail.indexOf(u[u.length - 1]) >= 0) u = u.substring(0, u.length - 1);
      if (u.length > 0) out.push({ text: u, isUrl: true });
      last = m.index + m[0].length;
    }
    if (last < cleaned.length) out.push({ text: cleaned.substring(last), isUrl: false });
    if (out.length === 0) out.push({ text: cleaned, isUrl: false });
    return out;
  }

  private openUrl(url: string): void {
    if (!url) return;
    // 贴吧帖子链接 → 进入 app 内帖子页
    const tidMatch = url.match(/(?:tieba\.baidu\.com\/p\/|tieba\.baidu\.com\/mo\/q\/view\?tid=)(\d+)/);
    if (tidMatch) {
      const tid = Number(tidMatch[1]);
      if (tid > 0) {
        AppRouter.navigate('thread', { threadId: String(tid), forumId: '0', forumName: '' });
        return;
      }
    }
    // 贴吧吧链接 → 进入 app 内吧页
    const kwMatch = url.match(/(?:tieba\.baidu\.com\/f\?(?:.*&)?kw=|tieba\.baidu\.com\/f\?kw=)([^&#]+)/);
    if (kwMatch) {
      const kw = decodeURIComponent(kwMatch[1]);
      if (kw) {
        AppRouter.navigate('forum', { forumName: kw, forumId: '0' });
        return;
      }
    }
    PreferencesManager.getInstance().getBoolean('open_links_in_app', true).then((inApp: boolean) => {
      if (inApp) {
        AppRouter.navigate('webview', { url: url });
      } else {
        this.openExternal(url);
      }
    }).catch(() => {
      AppRouter.navigate('webview', { url: url });
    });
  }

  private openExternal(url: string): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    if (!ctx) return;
    try {
      ctx.openLink(url).catch(() => {
        this.startAbilityExternal(url, ctx);
      });
      return;
    } catch (e) {}
    this.startAbilityExternal(url, ctx);
  }

  private startAbilityExternal(url: string, ctx: common.UIAbilityContext): void {
    if (!ctx) return;
    try {
      ctx.startAbility({
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: url
      }).catch((e: Error) => {
        console.error('TiebaLite: openExternal failed url=' + url.substring(0, 80) + ' err=' + JSON.stringify(e));
      });
    } catch (e) {
      console.error('TiebaLite: openExternal failed url=' + url.substring(0, 80) + ' err=' + JSON.stringify(e));
    }
  }

  private buildGroups(): ContentGroup[] {
    const groups: ContentGroup[] = [];
    let cur: Dict[] | null = null;
    let curIdx: number[] | null = null;
    for (let i = 0; i < this.contents.length; i++) {
      const raw = this.contents[i];
      const item: Dict = typeof raw === 'string' ? { type: 0, text: raw } : (raw.type !== undefined ? raw as Dict : { type: 0, text: String(raw.text || raw.c || '') });
      if (i < 5) console.info('TiebaLite: buildGroups item[' + i + '] type=' + item.type + ' text=' + String(item.text || item.c || '').substring(0, 30));
      if (this.isInlineType(Number(item.type))) {
        if (!cur) { cur = []; curIdx = []; }
        cur.push(item);
        curIdx!.push(i);
      } else {
        if (cur) { groups.push({ isInline: true, items: cur, origIndices: curIdx! }); cur = null; curIdx = null; }
        groups.push({ isInline: false, items: [item], origIndices: [i] });
      }
    }
    if (cur) groups.push({ isInline: true, items: cur, origIndices: curIdx! });
    console.info('TiebaLite: buildGroups groups=' + groups.length + ' firstGroup items=' + (groups[0]?.items.length || 0));
    return groups;
  }

  build() {
    Column() {
      ForEach(this.buildGroups(), (group: ContentGroup, gIdx: number) => {
        if (group.isInline) {
          Text() {
            ForEach(group.items, (item: Dict, gi: number) => {
              if (Number(item.type) === 0) {
                if (String(item.text || item.c || '') && this.isEmojiText(String(item.text || item.c || '')) && this.getEmojiUrlFromText(String(item.text || item.c || ''))) {
                  ImageSpan(this.getEmojiUrlFromText(String(item.text || item.c || '')).replace('https://', 'http://'))
                    .width(20).height(20).objectFit(ImageFit.Contain)
                    .verticalAlign(ImageSpanAlignment.CENTER)
} else if (String(item.text || item.c || '')) {
                  ForEach(this.splitUrlText(String(item.text || item.c || '')), (seg: UrlSeg) => {
                    if (seg.isUrl) {
                      ImageSpan($r('app.media.ic_link'))
                        .width(Math.round(14 * this.fontScale)).height(Math.round(14 * this.fontScale))
                        .objectFit(ImageFit.Contain).verticalAlign(ImageSpanAlignment.CENTER)
                      Span(' ' + seg.text)
                        .fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale))
                        .fontColor('#4477E0')
                        .onClick(() => { this.openUrl(seg.text); })
                    } else {
                      Span(seg.text)
                        .fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale))
                        .fontColor(textPrimary(this.isDark))
                    }
                  }, (seg: UrlSeg) => seg.text + (seg.isUrl ? '#u' : '#t'))
                }
              } else if (Number(item.type) === 40 && (item.c || item.text)) {
                ForEach(this.splitUrlText(String(item.c || item.text || '')), (seg: UrlSeg) => {
                  if (seg.isUrl) {
                    ImageSpan($r('app.media.ic_link'))
                      .width(Math.round(14 * this.fontScale)).height(Math.round(14 * this.fontScale))
                      .objectFit(ImageFit.Contain).verticalAlign(ImageSpanAlignment.CENTER)
                    Span(' ' + seg.text)
                      .fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale))
                      .fontColor('#4477E0')
                      .onClick(() => { this.openUrl(seg.text); })
                  } else {
                    Span(seg.text)
                      .fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale))
                      .fontColor(textPrimary(this.isDark))
                  }
                }, (seg: UrlSeg) => seg.text + (seg.isUrl ? '#u' : '#t'))
              } else if (Number(item.type) === 4 && (item.text || item.c)) {
                Span(String(item.text || item.c || ''))
                  .fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale))
                  .fontColor('#4477E0')
              } else if (Number(item.type) === 18 && (item.text || item.c) && this.getType18EmojiUrl(item)) {
                ImageSpan(this.getType18EmojiUrl(item).replace('https://', 'http://'))
                  .width(20).height(20).objectFit(ImageFit.Contain)
                  .verticalAlign(ImageSpanAlignment.CENTER)
              } else if (this.getEmojiUrl(item as Dict)) {
                ImageSpan(this.getEmojiUrl(item as Dict).replace('https://', 'http://'))
                  .width(20).height(20).objectFit(ImageFit.Contain)
                  .verticalAlign(ImageSpanAlignment.CENTER)
              } else if (Number(item.type) === 18) {
                Span(String(item.text || item.c || ''))
                  .fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale))
                  .fontColor(textPrimary(this.isDark))
              } else if (item.c || item.text) {
                Span(String(item.c || item.text || ''))
                  .fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale))
                  .fontColor(textPrimary(this.isDark))
              }
            })
          }
          .fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).lineHeight(Math.round(24 * this.fontScale)).letterSpacing(0.4).textAlign(TextAlign.Start).width('100%')
        } else {
          ForEach(group.items, (item: Dict, gi: number) => {
            if (Number(item.type) === 1 && String(item.link || '')) {
              Column() {
                Row() {
                  Image($r('app.media.ic_link')).width(Math.round(14 * this.fontScale)).height(Math.round(14 * this.fontScale))
                    .fillColor('#4477E0').margin({ right: 4 })
                  Text(String(item.text || item.link || ''))
                    .fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale))
                    .fontColor('#4477E0')
                    .onClick(() => { this.openUrl(String(item.link || '')); })
                }
                .alignItems(VerticalAlign.Center)
                .width('100%')
              }
              .width('100%')
              .margin({ top: 4, bottom: 4 })
            } else if (Number(item.type) === 1) {
              Column() {
                if (this.toHttps(this.getImgSrc(item))) {
                  Stack() {
Image(this.imgAllowed() ? this.toHttps(this.getImgSrc(item)) : '')
                      .width('100%')
                      .objectFit(ImageFit.Contain)
                      .borderRadius(8)
                      .backgroundColor(this.imgAllowed() ? Color.Transparent : blendWithBg('#4477E0', 0.06, this.isDark, '#1E1E1E'))

                    if (this.isGifItem(item)) {
                      Text('GIF').fontFamily(this.appFontFamily).fontSize(11).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
                        .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                        .backgroundColor('#CC000000').borderRadius(3)
                        .position({ top: 4, left: 4 })
                    }
                  }
                  .width('100%')
                  .margin({ top: 8, bottom: 8 })
                  .onClick(() => {
                    this.navigatePhotoView(group.origIndices[gi]);
                  })
                } else {
Text(String(item.text || item.c || ''))
                    .fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontColor(textPrimary(this.isDark)).lineHeight(Math.round(24 * this.fontScale)).letterSpacing(0.4).width('100%').padding({ top: 4, bottom: 4 })
                }
              }
              .width('100%')
            } else if (Number(item.type) === 5) {
              Column() {
                if (this.isFirstVideoGroup(gIdx) && this.firstVideoUrl) {
                  VideoPlayer({
                    videoUrl: this.firstVideoUrl,
                    posterUrl: this.firstVideoPoster,
                    autoPlay: this.shouldAutoPlayVideo(),
                    loop: true,
                    allowPip: true,
                    enableControls: true,
                    objectFit: ImageFit.Contain,
                    videoWidth: '100%',
                    videoHeight: '100%',
                    videoBorderRadius: 8,
                    onPositionChange: (sec: number) => { this.videoCurrentSec = sec; }
                  })
                    .width('100%')
                    .aspectRatio(this.getItemAspect(item))
                    .margin({ top: 8, bottom: 8 })
                } else if (this.resolveVideoUrl(item)) {
                  VideoPlayer({
                    videoUrl: this.resolveVideoUrl(item),
                    posterUrl: this.toHttps(String(item.bsrc || item.src || '')),
                    autoPlay: false,
                    loop: true,
                    allowPip: true,
                    enableControls: true,
                    objectFit: ImageFit.Contain,
                    videoWidth: '100%',
                    videoHeight: '100%',
                    videoBorderRadius: 8,
                    onPositionChange: (sec: number) => { this.videoCurrentSec = sec; }
                  })
                    .width('100%')
                    .aspectRatio(this.getItemAspect(item))
                    .margin({ top: 8, bottom: 8 })
                } else {
                  Stack() {
                    Image(this.imgAllowed() ? this.toHttps(String(item.bsrc || item.src || '')) : '')
                      .width('100%')
                      .borderRadius(8)
                      .objectFit(ImageFit.Contain)
                    Column() {
                      Image($r('app.media.ic_play_circle')).width(Math.round(48 * this.fontScale)).height(Math.round(48 * this.fontScale)).fillColor('#FFFFFF')
                    }
                    .width('100%').height('100%')
                    .justifyContent(FlexAlign.Center)
                    .alignItems(HorizontalAlign.Center)
                    Text(this.formatDuration(String(item.during_time || item.duration || item.duringTime || '')))
                      .fontFamily(this.appFontFamily).fontSize(12).fontColor('#FFFFFF').padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .backgroundColor('#CC000000').borderRadius(3).position({ bottom: 6, right: 6 })
                  }
                  .width('100%')
                  .aspectRatio(this.getItemAspect(item))
                    .margin({ top: 8, bottom: 8 })
                    .onClick(() => {
                      this.openVideo(item);
                    })
                }
              }
              .width('100%')
            } else if (Number(item.type) === 3 || Number(item.type) === 20) {
              Column() {
                if (this.toHttps(this.getImgSrc(item))) {
                  Stack() {
Image(this.imgAllowed() ? this.toHttps(this.getImgSrc(item)) : '')
                      .width('100%')
                      .objectFit(ImageFit.Contain)
                      .borderRadius(8)
                      .backgroundColor(this.imgAllowed() ? Color.Transparent : blendWithBg('#4477E0', 0.06, this.isDark, '#1E1E1E'))

                    if (this.isGifItem(item)) {
                      Text('GIF').fontFamily(this.appFontFamily).fontSize(11).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
                        .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                        .backgroundColor('#CC000000').borderRadius(3)
                        .position({ top: 4, left: 4 })
                    }
                  }
                  .width('100%')
                  .margin({ top: 8, bottom: 8 })
                    .onClick(() => {
                    this.navigatePhotoView(group.origIndices[gi]);
                  })
                } else {
                  Row() {
                    Image($r('app.media.ic_link')).width(Math.round(14 * this.fontScale)).height(Math.round(14 * this.fontScale))
                      .fillColor('#4477E0').margin({ right: 4 })
                    Text(String(item.text || item.c || ''))
                      .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale))
                      .fontColor('#4477E0')
                      .onClick(() => {
                        this.openUrl(String(item.link || item.text || ''));
                      })
                  }
                  .alignItems(VerticalAlign.Center)
                }
              }
              .width('100%')
            } else if (Number(item.type) === 4) {
              Row() {
                Image($r('app.media.ic_notifications')).width(Math.round(16 * this.fontScale)).height(Math.round(16 * this.fontScale)).fillColor(textPrimary(this.isDark))
                if (item.text && String(item.text).length > 0) {
                  Text(String(item.text))
                    .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textPrimary(this.isDark)).lineHeight(20)
                    .margin({ left: 4 })
                    .layoutWeight(1)
                } else {
                  Text(String(item.duringTime || item.during_time || '') + '')
                    .fontFamily(this.appFontFamily).fontSize(Math.round(13 * this.fontScale)).fontColor(textSecondary(this.isDark)).margin({ left: 6 })
                  Text('语音消息')
                    .fontFamily(this.appFontFamily).fontSize(Math.round(13 * this.fontScale)).fontColor('#4477E0').margin({ left: 4 })
                }
              }
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .backgroundColor(blendWithBg('#4477E0', 0.12, this.isDark, '#1E1E1E'))
              .borderRadius(8)
              .margin({ top: 2, bottom: 2 })
              .onClick(() => {
                const md5: string = String(item.voiceMD5 || item.voice_md5 || item.voiceMd5 || '');
                if (md5.length > 0) {
                  AppRouter.navigate('webview', { url: 'https://tiebac.baidu.com/c/p/voice?voice_md5=' + md5 + '&play_from=pb_voice_play' });
                } else if (item.link) {
                  AppRouter.navigate('webview', { url: String(item.link) });
                }
              })
            } else if (Number(item.type) === 8) {
              Text(String(item.text || ''))
                .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale))
                .fontColor('#4477E0')
                .onClick(() => {})
            } else {
              if (item.text || item.c) {
                if (this.isEmojiText(String(item.text || item.c || '')) && this.getEmojiUrlFromText(String(item.text || item.c || ''))) {
                  EmojiImage({ url: this.getEmojiUrlFromText(String(item.text || item.c || '')), emojiText: String(item.c || '') })
                    .width(20).height(20).flexShrink(0)
} else {
                Text(String(item.text || item.c || ''))
                  .fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale))
                  .fontColor(textPrimary(this.isDark)).lineHeight(Math.round(24 * this.fontScale)).letterSpacing(0.4).padding({ top: 2, bottom: 2 }).width('100%')
              }
              }
            }
          })
        }
      })
    }
    .width('100%')
  }

  private getType18EmojiUrl(item: Dict): string {
    const text = String(item.text || item.c || '');
    return text ? resolveEmojiIdFromMgr(text) : '';
  }

  private getImgSrc(item: Dict): string {
    return String(item.originSrc || item.src || item.origin_src || item.cdn_src || item.c || item.text || item.imgSrc || item.imageSrc || item.originalSrc || item.httpsSrc || '');
  }

  static resolveImageSrc(item: Dict): string {
    const u = String(item.originSrc || item.src || item.origin_src || item.cdn_src || item.c || item.text || item.imgSrc || item.imageSrc || item.originalSrc || item.httpsSrc || '');
    if (!u) return '';
    if (u.startsWith('https://')) return u;
    if (u.startsWith('http://')) return 'https://' + u.substring(7);
    if (u.startsWith('//')) return 'https:' + u;
    return u;
  }

  private isGifItem(item: Dict): boolean {
    const u = this.toHttps(String(item.origin_src || item.originSrc || item.src || item.c || ''));
    if (u.toLowerCase().includes('.gif')) return true;
    if (item.is_gif === 1 || item.gif === 1) return true;
    if (String(item.media_type || '').toLowerCase() === 'gif') return true;
    return false;
  }

  private imgAllowed(): boolean {
    if (this.imageLoadMode === 0) return true;
    if (this.imageLoadMode === 1) return this.netIsWifi;
    return false;
  }

  private toHttps(url: string): string {
    if (!url) return '';
    if (url.startsWith('https://')) return url;
    if (url.startsWith('http://')) return 'https://' + url.substring(7);
    if (url.startsWith('//')) return 'https:' + url;
    return url;
  }

  private getEmojiUrl(item: Dict): string {
    const directUrl = String(item.bsrc || item.src || item.icon || item.url || item.picUrl || item.thumbnail || item.c || '');
    if (directUrl.startsWith('http://') || directUrl.startsWith('https://') || directUrl.startsWith('//')) return this.toHttps(directUrl);
    const textId = String(item.text || '').trim();
    const name = String(item.c || '').trim();
    if (textId && name && textId !== name) {
      registerEmoji(name, textId);
    }
    const rawId = String(item.id || item.text || item.c || '').trim();
    if (!rawId) return '';
    const url = PbContentRender.resolveEmojiId(rawId);
    return url;
  }

  static resolveEmojiId(rawId: string): string {
    const id = rawId.replace(/[[\]【】「」『』《》（）()<>{}]/g, '').trim();
    if (!id) return '';
    const strippedId = id.replace(/^#+/, '');
    if (/^\d+$/.test(strippedId)) return 'http://static.tieba.baidu.com/tb/editor/images/client/image_emoticon' + strippedId + '.png';
    const knownPrefixes = ['image_emoticon', 'image_emotion', 'shoubai_emoji', 'tsj_emoji', 'tb_emoji', 'emoji_', 'bai_emoji', 'new_emoticon', 'tieba_emoji', 'emotion_', 'emoticon_'];
    if (/^\d+$/.test(id)) return 'http://static.tieba.baidu.com/tb/editor/images/client/image_emoticon' + id + '.png';
    const spaced = PbContentRender.getSpacedEmojiId(id);
    if (spaced) return 'http://static.tieba.baidu.com/tb/editor/images/client/' + spaced + '.png';
    if (knownPrefixes.some(p => id.startsWith(p))) return 'http://static.tieba.baidu.com/tb/editor/images/client/' + id + '.png';
    const mapped = getEmojiIdFromMap(id);
    if (mapped) return 'http://static.tieba.baidu.com/tb/editor/images/client/' + mapped + '.png';
    const encoded = encodeURIComponent(id);
    return 'http://static.tieba.baidu.com/tb/editor/images/client/' + encoded + '.png';
  }

  static getSpacedEmojiId(text: string): string {
    const id = text.replace(/[[\]【】「」『』《》（）()<>{}]/g, '').trim();
    const m = id.match(/^#?\s*emot(?:ion|icon)\s*[:：]?\s*(\d+)$/);
    return m ? 'image_emoticon' + m[1] : '';
  }

  private isEmojiText(text: string): boolean {
    const id = text.replace(/[[\]【】「」『』《》（）()<>{}]/g, '').trim();
    if (!id) return false;
    const strippedId = id.replace(/^#+/, '');
    const knownPrefixes = ['image_emoticon', 'image_emotion', 'shoubai_emoji', 'tsj_emoji', 'tb_emoji', 'emoji_', 'bai_emoji', 'new_emoticon', 'tieba_emoji', 'emotion_', 'emoticon_'];
    if (knownPrefixes.some(p => id.startsWith(p))) return true;
    if (/^\d+$/.test(strippedId)) return true;
    if (/^\d+$/.test(id)) return true;
    if (getEmojiIdFromMap(id)) return true;
    if (PbContentRender.getSpacedEmojiId(id)) return true;
    return false;
  }

  private getEmojiUrlFromText(text: string): string {
    return PbContentRender.resolveEmojiId(text);
  }

  private formatDuration(d: string): string {
    if (!d) return '';
    const secs = parseInt(d);
    if (isNaN(secs) || secs <= 0) return '';
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return m > 0 ? m + ':' + (s < 10 ? '0' : '') + s : '0:' + (s < 10 ? '0' : '') + s;
  }

  private getItemAspect(item: Dict): number {
    const w = Number(item.width || item.originWidth || 0);
    const h = Number(item.height || item.originHeight || 0);
    if (w > 0 && h > 0) return w / h;
    if (Number(item.type) === 5) return 16 / 9;
    return 1;
  }

  private resolveVideoUrl(item: Dict): string {
    const candidates: string[] = [
      String(item.origin_video_url || item.originVideoUrl || ''),
      String(item.video_url || item.videoUrl || ''),
      String(item.hevc_url || item.hevcUrl || ''),
      String(item.link || ''),
      String(item.src || '')
    ];
    const videoExts: string[] = ['.mp4', '.webm', '.3gp', '.mov', '.avi', '.m3u8'];
    let bestUrl = '';
    for (const url of candidates) {
      if (!url) continue;
      if (videoExts.some((e: string) => url.toLowerCase().endsWith(e)) ||
          url.toLowerCase().includes('.mp4') ||
          url.toLowerCase().includes('/video/') ||
          url.toLowerCase().includes('.m3u8')) {
        bestUrl = url;
        break;
      }
    }
    if (!bestUrl) return '';
    return bestUrl.startsWith('http://') ? 'https://' + bestUrl.substring(7) : bestUrl;
  }

  private isFirstVideoGroup(gIdx: number): boolean {
    const groups = this.buildGroups();
    for (let i = 0; i < groups.length; i++) {
      const items = groups[i].items;
      if (items.length > 0 && Number(items[0].type) === 5) {
        return i === gIdx;
      }
    }
    return false;
  }

  private shouldAutoPlayVideo(): boolean {
    if (this.autoPlayMode === 0) return true;
    if (this.autoPlayMode === 1) return this.isWifiNet;
    return false;
  }

  private openVideo(item: Dict): void {
    const bestUrl = this.resolveVideoUrl(item);
    console.info('TiebaLite: [V4] openVideo best=' + bestUrl + ' vid=' + String(item.vid || '') + ' link=' + String(item.link || ''));
    if (bestUrl) {
      AppRouter.navigate('videoview', { videoUrl: bestUrl, posterUrl: String(item.bsrc || item.src || ''), startPosition: Math.floor(this.videoCurrentSec), videoAspect: this.getItemAspect(item), videoDuration: Number(item.during_time || item.duration || item.duringTime || 0) || 0 });
    } else {
      const vid = String(item.vid || '');
      if (vid) {
        AppRouter.navigate('webview', { url: 'https://tieba.baidu.com/mo/v/?vid=' + vid });
      } else if (item.link) {
        AppRouter.navigate('webview', { url: String(item.link) });
      }
    }
  }

  private navigatePhotoView(clickedContentIndex: number): void {
    let imgIdx = 0;
    for (let i = 0; i < this.contents.length; i++) {
      const t = Number(this.contents[i].type);
      if (t === 1 || t === 3 || t === 20) {
        if (i === clickedContentIndex) break;
        imgIdx++;
      }
    }
    const cached: string[] = PhotoUrlCache.map.get(String(this.threadId)) || [];
    let urls: string[] = [];
    if (cached.length > 0) {
      urls = cached;
    } else if (this.allImageUrls.length > 0) {
      urls = this.allImageUrls;
    } else {
      for (let i = 0; i < this.contents.length; i++) {
        const item = this.contents[i];
        if (Number(item.type) === 1 || Number(item.type) === 3 || Number(item.type) === 20) {
          const u = this.toHttps(this.getImgSrc(item));
          if (u) urls.push(u);
        }
      }
    }
    if (urls.length === 0) return;
    const index = Math.min(Math.max(this.allImageStartIndex + imgIdx, 0), urls.length - 1);
    const params: Dict = { urls: urls, urlsJson: JSON.stringify(urls), index: index, threadId: String(this.threadId), forumId: String(this.forumId), forumName: this.forumName };
    AppRouter.navigate('photoview', params);
  }
}

export class AppRouter {
  static navigate: (page: string, params?: Dict) => void = () => {};
}
