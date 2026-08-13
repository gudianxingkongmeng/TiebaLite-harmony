import { Dict } from '../core/types/Dict';
import Avatar from './Avatar';
import ThreadImageGrid from './ThreadImageGrid';
import { buildPortraitUrl, getStr, getNum, getStrObj, blendWithWhite, blendWithBg, darkenColor, pageBg, cardBg, cardRadius, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../core/utils/DataHelper';
import router from '@ohos.router';
import { NavigationHelper } from '../core/utils/NavigationHelper';
import pasteboard from '@ohos.pasteboard';
import promptAction from '@ohos.promptAction';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import common from '@ohos.app.ability.common';

import { resolveEmojiId, isEmojiText, isInlineEmojiType, isValidEmojiId, getEmojiUrlForItem } from './EmojiManager';
import PreferencesManager from '../core/storage/PreferencesManager';
import { PhotoUrlCache } from '../core/utils/ThreadImageFetcher';
import ForumAvatarFetcher from '../core/utils/ForumAvatarFetcher';

interface MediaResult {
  urls: string[];
  items: Dict[];
}

@Component
export default struct ThreadCard {
  @StorageLink('fontScale') fontScale: number = 1.06;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  @StorageLink('secondaryColor') secondaryColor: string = '#575E71';
  @StorageLink('tertiaryColor') tertiaryColor: string = '#5F5791';
  @StorageLink('isDarkTheme') isDark: boolean = false;
  @StorageLink('showThreadPreview') showThreadPreview: boolean = true;
  @StorageLink('cardStyle') cardStyle: number = 0;
  @StorageLink('imageLoadMode') imageLoadMode: number = 0;
  @StorageLink('netIsWifi') netIsWifi: boolean = true;
  @Prop thread: Dict = {};
  @Prop isDeleted: boolean = false;
  @Prop noMedia: boolean = false;
  @Prop thumbRight: boolean = false;
  @Prop storeMode: boolean = false;
  @State liked: boolean = false;
  @State likeCount: number = 0;
  @State hasRichText: boolean = true;
  @State forumAvatarUrl: string = '';
  @StorageLink('likedVersion') @Watch('onLikedVersionChange') likedVersion: number = 0;
  onCardClick?: () => void;
  onForumClick?: () => void;
  private _logged: boolean = false;
  onAuthorClick?: () => void;
  onLikeClick?: (liked: boolean) => void;
  onShareClick?: (url: string) => void;
  hotRank?: number;

  private get fcMedia(): MediaResult {
    const fc = this.thread.firstPostContent as object;
    const fcArr: object[] = Array.isArray(fc) ? fc as object[] : [];
    return this.extractFirstPostMedia(fcArr);
  }

  aboutToAppear(): void {
    const agree = this.thread.agree as Dict | undefined;
    if (agree) {
      this.liked = Number(agree.hasAgree || agree.has_agree || 0) === 1;
    }
    this.likeCount = agree ? Number(agree.agreeNum || agree.agree_num || agree.count || agree.num || 0) : getNum(this.thread, 'agreeNum', 'agree_num', 'likeNum', 'like_num');
    this.refreshLocalLike();
    this.forumAvatarUrl = this.getForumAvatarSync();
    if (!this.forumAvatarUrl) {
      const forumName = this.getForumName();
      if (forumName) {
        ForumAvatarFetcher.get(forumName).then((url: string) => {
          if (url) this.forumAvatarUrl = url;
        });
      }
    }
    if (Object.keys(this.thread).length > 0) {
      const hasAbsArr = Array.isArray(this.thread._abstract) && (this.thread._abstract as Dict[]).length > 0;
      const hasFpcArr = Array.isArray(this.thread.firstPostContent) && (this.thread.firstPostContent as Dict[]).length > 0;
      const hasContentArr = Array.isArray(this.thread.content) && (this.thread.content as Dict[]).length > 0;
      const hasRichAbsArr = Array.isArray(this.thread.richAbstract) && (this.thread.richAbstract as Dict[]).length > 0;
      const hasRichAbs2Arr = Array.isArray(this.thread.rich_abstract) && (this.thread.rich_abstract as Dict[]).length > 0;
      const strFallback = getStr(this.thread, '_abstract', 'abstract', 'abstractText', 'first_post_content', 'firstPostContent', 'content', 'excerpt', 'richAbstract', 'rich_abstract');
      const gridUrls = this.getGridUrls();
      const hasVi = (this.thread.videoInfo || this.thread.video_info) !== undefined;
      const hasMedia = Array.isArray(this.thread.media);
      const rawArr: object[] = hasAbsArr ? (this.thread._abstract as object[]) : hasFpcArr ? (this.thread.firstPostContent as object[]) : hasRichAbsArr ? (this.thread.richAbstract as object[]) : hasRichAbs2Arr ? (this.thread.rich_abstract as object[]) : hasContentArr ? (this.thread.content as object[]) : [];
      this.hasRichText = rawArr.length === 0;
      for (let i = 0; i < rawArr.length; i++) {
        const t = Number((rawArr[i] as Dict).type);
        if (t !== 1 && t !== 3 && t !== 4 && t !== 5 && t !== 20) { this.hasRichText = true; break; }
      }
      console.info('TiebaLite: CardPreview absArr=' + hasAbsArr + ' fpcArr=' + hasFpcArr + ' contentArr=' + hasContentArr + ' richAbsArr=' + hasRichAbsArr + '/' + hasRichAbs2Arr + ' str="' + strFallback.substring(0, 60) + '" grid=' + gridUrls.length + ' vi=' + hasVi + ' media=' + hasMedia + ' hasRich=' + this.hasRichText);
      if (hasMedia) {
        console.info('TiebaLite: mediaLen=' + (this.thread.media as Dict[]).length);
        const mArr = this.thread.media as Dict[];
        for (let i = 0; i < mArr.length && i < 3; i++) {
          const m = mArr[i] as Dict;
          console.info('TiebaLite: media[' + i + '] type=' + String(m.type) + ' is_video=' + String(m.is_video) + ' vhsrc=' + String(m.vhsrc || m.vsrc || m.video_url || m.videoUrl || m.url || m.link || '').substring(0, 60) + ' src=' + String(m.src || m.origin_src || '').substring(0, 60) + ' keys=' + Object.keys(m).join(',').substring(0, 200));
        }
      }
      if (gridUrls.length > 0) console.info('TiebaLite: gridUrl0=' + gridUrls[0].substring(0, 120));
    }
  }

  private refreshLocalLike(): void {
    const tid = this.getTid();
    if (tid <= 0) return;
    const prefs = PreferencesManager.getInstance();
    void prefs.getString('liked_tid_' + tid, '').then((v: string) => {
      if (v === '1') this.liked = true;
      else if (v === '0') this.liked = false;
    }).catch(() => {});
    void prefs.getString('liked_count_tid_' + tid, '').then((c: string) => {
      const n = Number(c);
      if (c !== '' && !isNaN(n) && n >= 0) this.likeCount = n;
    }).catch(() => {});
  }

  onLikedVersionChange(): void {
    this.refreshLocalLike();
  }

  build() {
    Column() {
      if (!this.storeMode) {
        Row() {
          Avatar({
            portrait: buildPortraitUrl(this.getAuthorPortrait()),
            avatarSize: 36,
            defaultName: this.getAuthorName()
          })
          .onClick(() => {
            if (this.onAuthorClick) { this.onAuthorClick(); return; }
            const uid = this.getAuthorId();
            if (uid !== '0' && uid !== '') {
              NavigationHelper.navigate('pages/user/UserProfilePage', { uid: uid });
            }
          }, 12)
          Column() {
            Text(this.getAuthorName())
              .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(darkenColor(this.primaryColor, this.isDark ? 0.25 : 0.55)).fontWeight(FontWeight.Medium)
              .decoration({ type: this.isDeleted ? TextDecorationType.LineThrough : TextDecorationType.None })
            Text(this.formatTime(this.getTimeStr()))
              .fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textSecondary(this.isDark)).letterSpacing(1).margin({ top: 6 })
          }
          .margin({ left: 10 }).layoutWeight(1).alignItems(HorizontalAlign.Start)

          if (this.hotRank !== undefined) {
            Column() {
              Text(String(this.hotRank! + 1))
                .fontFamily(this.appFontFamily).fontSize(Math.round(18 * this.fontScale)).fontWeight(FontWeight.Bold)
                .fontColor(this.hotRank! === 0 ? '#FF0000' : this.hotRank! === 1 ? '#FF8800' : this.hotRank! === 2 ? '#FFCC00' : '#CCCCCC')
              Text(this.formatHotNum(getNum(this.thread, 'hotNum', 'hot_num')))
                .fontFamily(this.appFontFamily).fontSize(Math.round(10 * this.fontScale)).fontColor(this.hotRank! === 0 ? '#FF0000' : this.hotRank! === 1 ? '#FF8800' : this.hotRank! === 2 ? '#FFCC00' : '#CCCCCC')
                .margin({ top: 2 })
            }
            .width(44).alignItems(HorizontalAlign.Center)
          }
        }
        .width('100%')
      }

      if (this.storeMode) {
        Row() {
          Column() {
            if (this.thread.title !== undefined && this.thread.title !== null) {
              Text(getStr(this.thread, 'title'))
                .fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark))
                .lineHeight(Math.round(24 * this.fontScale)).letterSpacing(0.4).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
                .decoration({ type: this.isDeleted ? TextDecorationType.LineThrough : TextDecorationType.None })
            }

            Blank()

            if (this.getForumName()) {
              Row() {
                if (this.forumAvatarUrl) {
                  Image(this.imgAllowed() ? this.forumAvatarUrl : '')
                    .width(Math.round(16 * this.fontScale)).height(Math.round(16 * this.fontScale))
                    .borderRadius(4).objectFit(ImageFit.Cover).margin({ right: 6 })
                } else {
                  Image($r('app.media.ic_tieba_logo')).width(Math.round(16 * this.fontScale)).height(Math.round(16 * this.fontScale)).margin({ right: 6 })
                }
                Text(this.getForumName())
                  .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(this.tertiaryColor).fontWeight(FontWeight.Medium)
                  .letterSpacing(1)
                  .decoration({ type: this.isDeleted ? TextDecorationType.LineThrough : TextDecorationType.None })
              }
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(blendWithBg(this.tertiaryColor, 0.15, this.isDark, '#1E1E1E')).borderRadius(4)
              .alignSelf(ItemAlign.Start)
              .onClick(() => {
                if (this.onForumClick) { this.onForumClick(); return; }
                NavigationHelper.navigate('pages/forum/ForumPage', { forumName: this.getForumName(), forumId: getStr(this.thread, 'forumId', 'forum_id') });
              }, 12)
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .clip(true)
          .height(80)

          if (this.thumbRightUrl().length > 0) {
            Stack() {
              Image(this.imgAllowed() ? this.thumbRightUrl() : '')
                .width('100%').height('100%')
                .objectFit(ImageFit.Cover)
              if (this.thumbRightIsVideo()) {
                Image($r('app.media.ic_play')).width(24).height(24).fillColor('#FFFFFF')
              }
            }
            .width(80).height(80).borderRadius(8).clip(true)
            .margin({ left: 12 })
          }
        }
        .width('100%')
      } else {
        if (this.thread.title !== undefined && this.thread.title !== null) {
          Text(getStr(this.thread, 'title'))
            .fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark))
            .lineHeight(Math.round(24 * this.fontScale)).letterSpacing(0.4).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%').margin({ top: 8 })
            .decoration({ type: this.isDeleted ? TextDecorationType.LineThrough : TextDecorationType.None })
        }

        if (this.showThreadPreview) {
          if (this.thumbRight) {
            Row() {
              Column() {
                this.TextPreviewBlock()
              }
              .layoutWeight(3)
              .alignItems(HorizontalAlign.Start)
              .clip(true)
              .height(96)

              if (this.thumbRightUrl().length > 0) {
                Stack() {
                  Image(this.imgAllowed() ? this.thumbRightUrl() : '')
                    .width('100%').height('100%')
                    .objectFit(ImageFit.Cover)
                  if (this.thumbRightIsVideo()) {
                    Image($r('app.media.ic_play')).width(24).height(24).fillColor('#FFFFFF')
                  }
                }
                .width(96).height(96).borderRadius(8).clip(true)
                .margin({ left: 12 })
              }
            }
            .width('100%').margin({ top: 6 })
          } else {
            this.TextPreviewBlock()
          }
        }

        if (this.showThreadPreview && !this.noMedia && !this.thumbRight && (this.getGridUrls().length > 0 || this.getGridMedia().length > 0)) {
          ThreadImageGrid({
            urls: this.getGridUrls(),
            mediaItems: this.getGridMedia(),
            onOpenViewer: (i: number) => { this.openViewer(i); }
          })
        }

        if (this.getForumName()) {
          Row() {
            if (this.forumAvatarUrl) {
              Image(this.imgAllowed() ? this.forumAvatarUrl : '')
                .width(Math.round(16 * this.fontScale)).height(Math.round(16 * this.fontScale))
                .borderRadius(4).objectFit(ImageFit.Cover).margin({ right: 6 })
            } else {
              Image($r('app.media.ic_tieba_logo')).width(Math.round(16 * this.fontScale)).height(Math.round(16 * this.fontScale)).margin({ right: 6 })
            }
            Text(this.getForumName())
              .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(this.tertiaryColor).fontWeight(FontWeight.Medium)
              .letterSpacing(1)
              .decoration({ type: this.isDeleted ? TextDecorationType.LineThrough : TextDecorationType.None })
          }
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(blendWithBg(this.tertiaryColor, 0.15, this.isDark, '#1E1E1E')).borderRadius(4).margin({ top: 8 })
          .alignSelf(ItemAlign.Start)
          .onClick(() => {
            if (this.onForumClick) { this.onForumClick(); return; }
            NavigationHelper.navigate('pages/forum/ForumPage', { forumName: this.getForumName(), forumId: getStr(this.thread, 'forumId', 'forum_id') });
          }, 12)
        }

        Row() {
          Row() {
            Image($r('app.media.ic_share')).width(Math.round(16 * this.fontScale)).height(Math.round(16 * this.fontScale)).fillColor(textSecondary(this.isDark))
            Text(this.formatCount(getNum(this.thread, 'shareNum', 'share_num'))).fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textTertiary(this.isDark)).margin({ left: 3 })
          }
          .padding({ left: 6, right: 6, top: 4, bottom: 4 })
          .onClick(() => { this.shareToApps(); }, 12)
          this.ActionBtn($r('app.media.ic_reply'), this.formatCount(getNum(this.thread, 'replyNum', 'reply_num', 'commentNum', 'comment_num')), () => {
            const tid = getStr(this.thread, 'id', 'tid', 'threadId', 'thread_id');
            if (tid) {
              NavigationHelper.navigate('pages/thread/ThreadPage', { threadId: tid });
            }
          })
          Row() {
            if (this.liked) {
              Image($r('app.media.ic_favorite')).width(Math.round(18 * this.fontScale)).height(Math.round(18 * this.fontScale)).fillColor('#FF4444')
            } else {
              Image($r('app.media.ic_favorite')).width(Math.round(18 * this.fontScale)).height(Math.round(18 * this.fontScale)).fillColor(textSecondary(this.isDark)).opacity(0.5)
            }
            if (this.likeCount > 0) {
              Text(this.formatCount(this.likeCount)).fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(this.liked ? '#FF4444' : textTertiary(this.isDark)).margin({ left: 3 })
            }
          }
          .padding({ left: 6, right: 6, top: 4, bottom: 4 })
          .onClick(() => {
            this.liked = !this.liked;
            this.likeCount = Math.max(0, this.likeCount + (this.liked ? 1 : -1));
            const tid = this.getTid();
            if (tid > 0) {
              const prefs = PreferencesManager.getInstance();
              void prefs.putString('liked_tid_' + tid, this.liked ? '1' : '0').catch(() => {});
              void prefs.putString('liked_count_tid_' + tid, String(this.likeCount)).catch(() => {});
            }
            try { AppStorage.SetOrCreate('likedVersion', (AppStorage.Get<number>('likedVersion') ?? 0) + 1); } catch (e) {}
            if (this.onLikeClick) this.onLikeClick(this.liked);
          }, 12)
        }
        .width('100%').justifyContent(FlexAlign.SpaceAround).margin({ top: 8 })
      }
    }
    .width('100%')
    .padding(this.cardStyle === 1 ? { left: 16, right: 16, top: 14, bottom: 14 } : 16)
    .backgroundColor(this.cardStyle === 1 ? Color.Transparent : cardBg(this.isDark))
    .borderRadius(this.cardStyle === 1 ? 0 : cardRadius(8))
    .border(this.cardStyle === 1 ? { width: { bottom: 0.5 }, color: dividerColor(this.isDark) } : { width: 0, color: Color.Transparent })
    .onClick(() => { if (this.onCardClick) this.onCardClick(); }, 12)
    .animation({ duration: 250, curve: Curve.FastOutSlowIn })
  }

  @Builder
  TextPreviewBlock() {
    if (Array.isArray(this.thread._abstract) && (this.thread._abstract as Dict[]).length > 0) {
      if (this.hasRichText) this.RichPreview(this.thread._abstract as Dict[])
    } else if (Array.isArray(this.thread.firstPostContent) && (this.thread.firstPostContent as Dict[]).length > 0) {
      if (this.hasRichText) this.RichPreview(this.thread.firstPostContent as Dict[])
    } else if (Array.isArray(this.thread.richAbstract) && (this.thread.richAbstract as Dict[]).length > 0) {
      if (this.hasRichText) this.RichPreview(this.thread.richAbstract as Dict[])
    } else if (Array.isArray(this.thread.rich_abstract) && (this.thread.rich_abstract as Dict[]).length > 0) {
      if (this.hasRichText) this.RichPreview(this.thread.rich_abstract as Dict[])
    } else if (Array.isArray(this.thread.content) && (this.thread.content as Dict[]).length > 0) {
      if (this.hasRichText) this.RichPreview(this.thread.content as Dict[])
    } else if (this.hasRichText && getStr(this.thread, '_abstract', 'abstract', 'abstractText', 'first_post_content', 'firstPostContent', 'content', 'excerpt', 'richAbstract', 'rich_abstract')) {
      Text(getStr(this.thread, '_abstract', 'abstract', 'abstractText', 'first_post_content', 'firstPostContent', 'content', 'excerpt', 'richAbstract', 'rich_abstract'))
        .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(textSecondary(this.isDark)).lineHeight(Math.round(24 * this.fontScale)).letterSpacing(0.4).textAlign(TextAlign.Start).maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%').margin({ top: 6 })
        .decoration({ type: this.isDeleted ? TextDecorationType.LineThrough : TextDecorationType.None })
    }
  }

  @Builder
  ActionBtn(iconRes: Resource, label: string, action: () => void) {
    Row() {
      Image(iconRes).width(Math.round(16 * this.fontScale)).height(Math.round(16 * this.fontScale)).fillColor(textSecondary(this.isDark))
      if (label && label.length > 0) {
        Text(label).fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textTertiary(this.isDark)).margin({ left: 3 })
      }
    }
    .padding({ left: 6, right: 6, top: 4, bottom: 4 })
    .onClick(() => { action(); }, 12)
  }

  private isNotNumeric(s: string): boolean {
    for (let i = 0; i < s.length; i++) { const c = s.charCodeAt(i); if (c < 48 || c > 57) return true; }
    return false;
  }

  private getAuthorName(): string {
    const author = this.thread.author as Dict;
    if (Object.keys(this.thread).length > 0 && !this._logged) {
      this._logged = true;
      console.info('TiebaLite: ThreadCard keys=' + Object.keys(this.thread).join(',') + ' hasAuthor=' + (author !== undefined));
      if (author) console.info('TiebaLite: author keys=' + Object.keys(author).join(','));
    }
    // Try author sub-object first (API原生结构)
    if (author) {
      for (const k of ['name', 'nameShow', 'name_show', 'nickname', 'userName', 'user_name', 'showName', 'show_name', 'un', 'username']) {
        const v = author[k];
        if (typeof v === 'string' && v.length > 0 && v.length < 80 && (v.length > 1 || this.isNotNumeric(v))) return v;
      }
      // Fallback: skip pure-numeric fields (like id, user_id)
      for (const k of Object.keys(author)) {
        const v = author[k];
        if (typeof v === 'string' && v.length > 0 && v.length < 80 && this.isNotNumeric(v) && !k.includes('id') && !k.includes('num')) return v;
      }
    }
    // Flat fields on thread
    for (const k of ['authorName', 'author_name', 'nickname', 'userName', 'user_name', 'un', 'username', 'name']) {
      const v = this.thread[k];
      if (typeof v === 'string' && v.length > 0 && v.length < 80 && (v.length > 1 || this.isNotNumeric(v))) return v;
    }
    // firstPostInfo author
    const firstPost = this.thread.firstPostInfo as Dict || this.thread.first_post_info as Dict || {};
    const fpiAuthor = firstPost.author as Dict || {};
    for (const k of ['name', 'nameShow', 'name_show', 'nickname', 'authorName', 'author_name']) {
      const v = fpiAuthor[k] || firstPost[k];
      if (typeof v === 'string' && v.length > 0 && v.length < 80 && (v.length > 1 || this.isNotNumeric(v))) return v;
    }
    return '';
  }

  private getAuthorPortrait(): string {
    const author = this.thread.author as Dict;
    if (author) {
      for (const k of ['portrait', 'user_portrait', 'avatar', 'avatarUrl', 'portraitUrl', 'userPortrait', 'userAvatar']) {
        const v = author[k];
        if (typeof v === 'string' && v.length > 0 && v.length < 200 && (v.startsWith('http') || v.length > 2)) return v;
      }
      for (const k of Object.keys(author)) {
        const v = author[k];
        if (typeof v === 'string' && v.length > 0 && v.length < 200 && (k.includes('portrait') || k.includes('avatar') && (v.startsWith('http') || v.length > 2))) return v;
      }
    }
    for (const k of ['authorPortrait', 'author_portrait', 'portrait', 'userPortrait', 'user_portrait', 'avatar', 'avatarUrl', 'portraitUrl']) {
      const v = this.thread[k];
      if (typeof v === 'string' && v.length > 0 && v.length < 200) return v;
    }
    const firstPost = this.thread.firstPostInfo as Dict || this.thread.first_post_info as Dict || {};
    const fpiAuthor = firstPost.author as Dict || {};
    for (const k of ['portrait', 'user_portrait', 'avatar', 'authorPortrait', 'author_portrait']) {
      const v = fpiAuthor[k] || firstPost[k];
      if (typeof v === 'string' && v.length > 0 && v.length < 200) return v;
    }
    return '';
  }

  private getAuthorId(): string {
    const author = this.thread.author as Dict;
    if (author) {
      const id = getStr(author, 'id', 'user_id', 'uid', 'userId');
      if (id) return id;
    }
    return getStr(this.thread, 'authorId', 'author_id', 'uid', 'userId', 'user_id', 'authorUid', 'author_uid');
  }

  private openViewer(index: number): void {
    const urls = this.getGridUrls();
    if (urls.length === 0) return;
    const media = this.getGridMedia();
    if (index < media.length) {
      const m = media[index] as Record<string, Object>;
      const isVideo = Number(m.is_video || m.isVideo || 0) === 1 || Number(m.type || 0) === 5 || String(m.type) === 'flash' || String(m.media_type || '').toLowerCase() === 'video';
      if (isVideo) {
        const vUrl = this.getMediaVideoUrl(m);
        if (vUrl) {
          const mw = Number(m.width || m.originWidth || 0);
          const mh = Number(m.height || m.originHeight || 0);
          const mAspect = (mw > 0 && mh > 0) ? mw / mh : 16 / 9;
          NavigationHelper.navigate('pages/videoview/VideoViewPage', { videoUrl: vUrl, posterUrl: urls[index] || '', startPosition: 0, videoAspect: mAspect });
          return;
        }
      }
    }
    const tid = Number(getStr(this.thread, 'id', 'tid', 'threadId', 'thread_id') || 0);
    const cached: string[] = PhotoUrlCache.map.get(String(tid)) || [];
    const list = cached.length > 0 ? cached : urls;
    const i = Math.min(Math.max(index, 0), list.length - 1);
    const params: Dict = { urls: list, index: i, threadId: String(tid), forumId: getStr(this.thread, 'forumId', 'forum_id'), forumName: this.getForumName() };
    NavigationHelper.navigate('pages/photoview/PhotoViewPage', params);
  }

  private getMediaVideoUrl(m: Record<string, Object>): string {
    const candidates: string[] = [
      getStr(m, 'origin_video_url', 'originVideoUrl'),
      getStr(m, 'video_url', 'videoUrl'),
      getStr(m, 'vhsrc'),
      getStr(m, 'vsrc'),
      getStr(m, 'hevc_url', 'hevcUrl'),
      getStr(m, 'link'),
      getStr(m, 'src', 'origin_src')
    ];
    for (const url of candidates) {
      if (!url) continue;
      if (url.toLowerCase().includes('.mp4') || url.toLowerCase().includes('.webm') ||
          url.toLowerCase().includes('.3gp') || url.toLowerCase().includes('.mov') ||
          url.toLowerCase().includes('.m3u8') || url.toLowerCase().includes('/video/')) {
        return url.startsWith('http://') ? 'https://' + url.substring(7) : url;
      }
    }
    return '';
  }

  private extractVideoCover(videoItem: Dict): string {
    const poster = getStr(videoItem, 'bsrc', 'vpic', 'poster', 'posterUrl', 'cover', 'coverUrl', 'thumbnail', 'thumbnailUrl', 'photo', 'pic_url', 'picUrl', 'bigPic', 'originPic');
    if (poster && !this.isVideoUrl(poster)) return poster;
    const src = getStr(videoItem, 'vsrc', 'vhsrc', 'src', 'originSrc', 'videoUrl', 'video_url', 'url');
    if (src && !this.isVideoUrl(src)) return src;
    if (src && this.isVideoUrl(src)) {
      const jpg = src.replace(/\.(mp4|webm|3gp|mov|avi)(\?.*)?$/i, '.jpg');
      if (jpg !== src) return jpg;
    }
    return '';
  }

  private getGridMedia(): Dict[] {
    const vi = (this.thread.videoInfo || this.thread.video_info) as Dict;
    if (vi) {
      return [{
        is_video: 1,
        type: 5,
        vhsrc: getStr(vi, 'videoUrl', 'video_url', 'videoSrc', 'url', 'link'),
        src: getStr(vi, 'thumbnailUrl', 'thumbnail_url', 'poster', 'cover')
      }];
    }
    const raw = this.thread.firstPostContent || this.thread.first_post_content || this.thread.richAbstract || this.thread.rich_abstract || this.thread._abstract || this.thread.abstract || this.thread.content;
    if (Array.isArray(raw)) {
      const out: Dict[] = [];
      const arr = raw as Dict[];
      for (const c of arr) {
        const t = Number(c.type);
        if (t === 1 || t === 3 || t === 5) {
          out.push(c);
        } else {
          const u = getStr(c, 'originSrc', 'src', 'origin_src', 'bigPic', 'big_pic', 'smallPic', 'small_pic');
          if (u && !this.isVideoUrl(u)) out.push(c);
        }
      }
      if (out.length > 0) return out;
    }
    const mediaVal = this.thread.media;
    if (Array.isArray(mediaVal)) {
      const out: Dict[] = [];
      for (const m of mediaVal as Dict[]) {
        const mediaUrl = getStr(m, 'vhsrc', 'vsrc', 'video_url', 'videoUrl', 'url', 'link');
        const isVideo = Number(m.is_video || m.isVideo || 0) === 1 || Number(m.type || 0) === 5 || String(m.type) === 'flash' || String(m.media_type || '').toLowerCase() === 'video' || (mediaUrl ? this.isVideoUrl(mediaUrl) : false);
        if (isVideo) {
          out.push(m);
        } else {
          const src = getStr(m, 'originSrc', 'src', 'origin_src', 'bigPic', 'big_pic', 'smallPic', 'small_pic');
          if (src) out.push(m);
        }
      }
      if (out.length > 0) return out;
    }
    return [];
  }

  private getGridUrls(): string[] {
    const vi = (this.thread.videoInfo || this.thread.video_info) as Dict;
    if (vi) {
      const thumb = getStr(vi, 'thumbnailUrl', 'thumbnail_url', 'poster', 'cover');
      if (thumb && !this.isVideoUrl(thumb)) return [this.upscaleImageUrl(thumb)];
    }
    const found = this.tryExtractUrls(this.thread.firstPostContent || this.thread.first_post_content || this.thread.richAbstract || this.thread.rich_abstract || this.thread._abstract || this.thread.abstract || this.thread.content || []);
    if (found.length > 0) return found;
    const mediaVal = this.thread.media;
    if (Array.isArray(mediaVal)) {
      const mu: string[] = [];
      const mediaLen = mediaVal.length;
      for (let i = 0; i < mediaLen; i++) {
        const m = mediaVal[i] as Record<string, Object>;
        const mediaUrl = getStr(m, 'vhsrc', 'vsrc', 'video_url', 'videoUrl', 'url', 'link');
        const isVideo = Number(m.is_video || m.isVideo || 0) === 1 || Number(m.type || 0) === 5 || String(m.media_type || '').toLowerCase() === 'video' || (mediaUrl ? this.isVideoUrl(mediaUrl) : false);
        if (isVideo) {
          const cover = this.extractVideoCover(m as Dict);
          if (cover) mu.push(this.upscaleImageUrl(cover));
        } else {
          const src = getStr(m, 'originSrc', 'src', 'origin_src', 'bigPic', 'big_pic', 'smallPic', 'small_pic');
          if (src) mu.push(this.upscaleImageUrl(src));
        }
      }
      if (mu.length > 0) return mu;
    }
    const rawImg = this.thread.imageUrls;
    if (Array.isArray(rawImg)) return (rawImg as string[]).map(u => this.upscaleImageUrl(u));
    return [];
  }

  private tryExtractUrls(raw: object): string[] {
    const arr: object[] = Array.isArray(raw) ? raw as object[] : [];
    const urls: string[] = [];
    for (const c of arr) {
      const cd = c as Dict;
      const val = cd['type'];
      const t = Number(val);
      if (t === 0 || t === 2 || t === 4 || t === 6 || t === 7 || t === 9 || t === 10 || t === 11 || t === 12 || t === 13) {
        continue;
      }
      if (t === 1 || t === 3) {
        const u = getStr(cd, 'originSrc', 'src', 'origin_src', 'cdn_src', 'c', 'bigPic', 'big_pic', 'smallPic', 'small_pic', 'url', 'link');
        if (u) urls.push(this.upscaleImageUrl(u));
      } else if (t === 5) {
        const cover = this.extractVideoCover(cd);
        if (cover) urls.push(this.upscaleImageUrl(cover));
      } else {
        const u = getStr(cd, 'originSrc', 'src', 'origin_src', 'bigPic', 'big_pic', 'smallPic', 'small_pic');
        if (u && !this.isVideoUrl(u)) urls.push(this.upscaleImageUrl(u));
      }
    }
    return urls;
  }

  private imgAllowed(): boolean {
    if (this.imageLoadMode === 0) return true;
    if (this.imageLoadMode === 1) return this.netIsWifi;
    return false;
  }

  private thumbRightUrl(): string {
    const urls = this.getGridUrls();
    return urls.length > 0 ? urls[0] : '';
  }

  private thumbRightIsVideo(): boolean {
    const media = this.getGridMedia();
    if (media.length === 0) return false;
    const m = media[0] as Dict;
    const mediaUrl = getStr(m, 'vhsrc', 'vsrc', 'video_url', 'videoUrl', 'url', 'link');
    return Number(m.is_video || m.isVideo || 0) === 1 || Number(m.type || 0) === 5 || (mediaUrl ? this.isVideoUrl(mediaUrl) : false);
  }

  private tryScanTopLevel(): string[] {
    const vi = (this.thread.videoInfo || this.thread.video_info) as Dict;
    if (vi) {
      const thumb = getStr(vi, 'thumbnailUrl', 'thumbnail_url', 'poster', 'cover');
      if (thumb && !this.isVideoUrl(thumb)) return [this.upscaleImageUrl(thumb)];
    }
    const keys: string[] = Object.keys(this.thread);
    for (const key of keys) {
      const kLower = key.toLowerCase();
      if (kLower.includes('icon') || kLower.includes('ribbon') || kLower.includes('decoration')) continue;
      if (kLower.includes('video') || kLower.includes('cover') || kLower.includes('poster') || kLower === 'thumbnail' || kLower.includes('thumb') || kLower.includes('image')) {
        const v = (this.thread as Dict)[key];
        if (typeof v === 'string' && v.length > 0 && v.length < 500) {
          if (!this.isVideoUrl(v) && this.looksLikeUrl(v)) return [this.upscaleImageUrl(v)];
        }
        if (typeof v === 'object' && v !== null) {
          const obj = v as Dict;
          const t = getStr(obj, 'thumbnailUrl', 'thumbnail_url', 'poster', 'cover', 'srcPic', 'bigPic', 'originPic');
          if (t && !this.isVideoUrl(t)) return [this.upscaleImageUrl(t)];
          const found = this.scanObjectForUrls(obj);
          if (found) return [this.upscaleImageUrl(found)];
        }
      }
    }
    const found = this.scanObjectForUrls(this.thread);
    if (found) return [this.upscaleImageUrl(found)];
    return [];
  }

  private looksLikeUrl(s: string): boolean {
    return s.startsWith('http://') || s.startsWith('https://') || s.startsWith('//');
  }

  private scanObjectForUrls(obj: Dict, depth: number = 0): string | null {
    if (!obj || typeof obj !== 'object' || depth > 3) return null;
    for (const key of Object.keys(obj)) {
      const kLower = key.toLowerCase();
      if (kLower.includes('portrait') || kLower.includes('avatar') || kLower.includes('mb_') || kLower.includes('vip') || kLower.includes('badge') || kLower.includes('medal') || kLower.includes('icon') || kLower.includes('ribbon') || kLower.includes('decoration')) continue;
      const v = obj[key];
      if (typeof v === 'string' && v.length > 10 && v.length < 500 && this.looksLikeUrl(v)) {
        if (!this.isVideoUrl(v) && !kLower.includes('portrait') && !kLower.includes('avatar')) {
          return v;
        }
      }
      if (typeof v === 'object' && v !== null) {
        const sub = this.scanObjectForUrls(v as Dict, depth + 1);
        if (sub) return sub;
      }
    }
    return null;
  }

  private isVideoUrl(url: string): boolean {
    const videoExts: string[] = ['.mp4', '.webm', '.3gp', '.mov', '.avi', '.m3u8'];
    const qIdx = url.indexOf('?');
    const path = qIdx >= 0 ? url.substring(0, qIdx) : url;
    const slashIdx = path.lastIndexOf('/');
    const filename = slashIdx >= 0 ? path.substring(slashIdx) : path;
    const lower = filename.toLowerCase();
    return videoExts.some(e => lower.endsWith(e));
  }

  private upscaleImageUrl(url: string): string {
    let u = url.startsWith('https://') ? url : url.startsWith('http://') ? 'https://' + url.substring(7) : 'https:' + url;
    u = u.replace(/\/w%3D\d+\//g, '/');
    u = u.replace(/_(1024|580|92|128|256|320|480|640|720|800|960|1080|1200|1440|1920|2048)(?=\.\w+(\?|$))/g, '');
    const qIdx = u.indexOf('?');
    if (qIdx >= 0) {
      const base = u.substring(0, qIdx);
      const query = u.substring(qIdx + 1);
      const params = query.split('&');
      const filtered = params.filter(p => {
        const kv = p.split('=');
        const key = kv[0].toLowerCase();
        return key !== 'tb' && key !== 'w' && key !== 'h';
      });
      if (filtered.length < params.length) {
        u = filtered.length > 0 ? base + '?' + filtered.join('&') : base;
      }
    }
    return u;
  }

  private resolveMediaUrls2(): string[] {
    const items = this.thread.media as object;
    if (!items || !Array.isArray(items)) return [];
    return items.map((m: Dict) => {
      const src = getStr(m, 'src', 'originSrc', 'origin_src', 'bigPic', 'big_pic', 'smallPic', 'small_pic');
      if (src.startsWith('https://')) return src;
      if (src.startsWith('http://')) return 'https://' + src.substring(7);
      return 'https:' + src;
    });
  }

  private extractFirstPostMedia(contents: object[]): MediaResult {
    const urls: string[] = [];
    const items: Dict[] = [];
    if (!contents || !Array.isArray(contents)) return { urls, items };
    for (const c of contents) {
      const t = Number((c as Dict).type);
      if (t === 1 || t === 3) {
        const u = getStr(c as Dict, 'originSrc', 'src', 'origin_src', 'cdn_src', 'c');
        if (u) { urls.push(this.upscaleImageUrl(u)); items.push(c as Dict); }
      } else if (t === 5) {
        const poster = getStr(c as Dict, 'bsrc', 'src');
        if (poster) { urls.push(this.upscaleImageUrl(poster)); items.push(c as Dict); }
      }
    }
    return { urls, items };
  }

  @Builder
  RichPreview(items: Dict[]) {
    Text() {
      ForEach(items, (item: Dict) => {
        if (Number(item.type) === 1 || Number(item.type) === 3 || Number(item.type) === 4 || Number(item.type) === 5 || Number(item.type) === 20) {
        } else if (Number(item.type) === 0) {
          if (isEmojiText(String(item.text || item.c || '')) && resolveEmojiId(String(item.text || item.c || ''))) {
            ImageSpan(resolveEmojiId(String(item.text || item.c || '')).replace('https://', 'http://'))
              .width(20).height(20).objectFit(ImageFit.Contain)
              .verticalAlign(ImageSpanAlignment.CENTER)
          } else if (item.text || item.c) {
            Span(String(item.text || item.c || ''))
          }
        } else if (isInlineEmojiType(Number(item.type)) && isValidEmojiId(String(item.id || item.text || item.c || '')) && getEmojiUrlForItem(item)) {
          ImageSpan(getEmojiUrlForItem(item).replace('https://', 'http://'))
            .width(20).height(20).objectFit(ImageFit.Contain)
            .verticalAlign(ImageSpanAlignment.CENTER)
        } else if (item.c || item.text) {
          Span(String(item.c || item.text || ''))
        }
      })
    }
    .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(textSecondary(this.isDark)).lineHeight(Math.round(24 * this.fontScale)).letterSpacing(0.4).textAlign(TextAlign.Start).maxLines(3)
    .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%').margin({ top: 6 })
    .decoration({ type: this.isDeleted ? TextDecorationType.LineThrough : TextDecorationType.None })
  }

  private getTid(): number {
    return Number(this.thread.id || this.thread.tid || this.thread.threadId || this.thread.thread_id || 0);
  }

  private getAgreeCount(): number {
    const agree = this.thread.agree as Dict | undefined;
    if (agree) {
      const n = getNum(agree, 'agreeNum', 'agree_num', 'count', 'num');
      if (n > 0) return n;
    }
    return getNum(this.thread, 'agreeNum', 'agree_num', 'likeNum', 'like_num');
  }

  private getForumName(): string {
    const fi = this.thread.forumInfo as Dict | undefined;
    if (fi) return getStr(fi, 'name', 'forumName', 'forum_name');
    const fn = this.thread.forumName || this.thread.forum_name;
    if (typeof fn === 'string') return fn;
    if (fn && typeof fn === 'object') return getStr(fn as Dict, 'name', 'forumName', 'forum_name');
    const forum = this.thread.forum as Dict | undefined;
    if (forum) return getStr(forum, 'name', 'forumName', 'forum_name');
    return getStrObj(this.thread, 'fname', 'forum_name', 'forumName', 'forum');
  }

  private getForumAvatarSync(): string {
    const fa = getStr(this.thread, 'forum_avatar', 'forumAvatar', 'forumAvatarUrl', 'forum_avatar_url', 'favatar');
    if (fa) return fa;
    const fi = this.thread.forumInfo as Dict | undefined;
    if (fi) {
      const a = getStr(fi, 'avatar', 'head', 'forum_avatar', 'forumAvatar', 'icon', 'img', 'picture');
      if (a) return a;
    }
    const forum = this.thread.forum as Dict | undefined;
    if (forum) return getStr(forum, 'avatar', 'head', 'forum_avatar', 'forumAvatar', 'icon', 'img', 'picture');
    return '';
  }

  private getShareUrl(): string {
    const tid = getStr(this.thread, 'id', 'tid', 'threadId', 'thread_id');
    if (!tid) return '';
    return 'https://tieba.baidu.com/p/' + tid;
  }

  private copyLink(): void {
    const url = this.getShareUrl();
    if (!url) return;
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, url);
    const pb = pasteboard.getSystemPasteboard();
    void pb.setData(data);
    promptAction.showToast({ message: '链接已复制', duration: 1500 });
    if (this.onShareClick) this.onShareClick(url);
  }

  private shareToApps(): void {
    const url = this.getShareUrl();
    if (!url) return;
    const titleStr: string = getStr(this.thread, 'title', 'threadTitle', 'thread_title') || '';
    try {
      const shareData: systemShare.SharedData = new systemShare.SharedData({
        utd: utd.UniformDataType.HYPERLINK,
        content: url,
        title: titleStr
      });
      const controller: systemShare.ShareController = new systemShare.ShareController(shareData);
      const context = getContext(this) as common.UIAbilityContext;
      controller.show(context, {
        previewMode: systemShare.SharePreviewMode.DEFAULT,
        selectionMode: systemShare.SelectionMode.SINGLE
      }).catch((_err: Error) => {
        const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, url);
        const pb = pasteboard.getSystemPasteboard();
        void pb.setData(data);
        promptAction.showToast({ message: '链接已复制到剪贴板', duration: 1500 });
      });
    } catch (_e) {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, url);
      const pb = pasteboard.getSystemPasteboard();
      void pb.setData(data);
      promptAction.showToast({ message: '链接已复制到剪贴板', duration: 1500 });
    }
    if (this.onShareClick) this.onShareClick(url);
  }

  private formatCount(n: number): string {
    if (n <= 0) return '';
    if (n >= 10000) return (n / 10000).toFixed(1) + 'w';
    return String(n);
  }

  private formatHotNum(n: number): string {
    if (n <= 0) return '';
    if (n >= 10000) return (n / 10000).toFixed(1) + '万';
    if (n >= 1000) return (n / 1000).toFixed(1) + '千';
    return String(n);
  }

  private getTimeStr(): string {
    const t = getStr(this.thread, 'lastTimeInt', 'createTime', 'create_time', 'lastTime', 'last_time', 'lastTimeStr', 'last_time_str');
    if (t) return t;
    const post = this.thread.firstPostInfo as Dict || this.thread.first_post_info as Dict || {};
    return getStr(post, 'postTime', 'post_time', 'createTime', 'create_time');
  }

  private formatTime(timeStr: string): string {
    if (!timeStr) return '';
    const ts = Number(timeStr);
    if (!isNaN(ts)) {
      const d = new Date(ts > 1e12 ? ts : ts * 1000);
      return this.relativeTime(d);
    }
    const d = new Date(timeStr.split('-').join('/'));
    if (!isNaN(d.getTime())) return this.relativeTime(d);
    return timeStr;
  }

  private relativeTime(d: Date): string {
    const now = new Date();
    const diff = now.getTime() - d.getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 1) return '刚刚';
    if (mins < 60) return mins + '分钟前';
    const hours = Math.floor(diff / 3600000);
    const pad = (n: number): string => n < 10 ? '0' + n : String(n);
    if (d.getDate() === now.getDate() && d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear()) {
      return pad(d.getHours()) + ':' + pad(d.getMinutes());
    }
    const yesterday = new Date(now);
    yesterday.setDate(yesterday.getDate() - 1);
    if (d.getDate() === yesterday.getDate() && d.getMonth() === yesterday.getMonth() && d.getFullYear() === yesterday.getFullYear()) {
      return '昨天 ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
    }
    if (d.getFullYear() === now.getFullYear()) {
      return pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
    }
    return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
  }
}
