import router from '@ohos.router';
import { KeyboardAvoidMode } from '@ohos.arkui.UIContext';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import promptAction from '@ohos.promptAction';
import AddPostRepository from '../../core/repository/AddPostRepository';
import HotTopicRepository from '../../core/repository/HotTopicRepository';
import AccountManager, { Account } from '../../core/auth/AccountManager';
import { Dict } from '../../core/types/Dict';
import { blendWithBg, blendWithWhite, textAccent, pageBg, cardBg, textPrimary, textSecondary, textTertiary, dividerColor, darkenColor, shadowColor } from '../../core/utils/DataHelper';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';
import { uploadChunked, uploadVideoToTieba } from '../../core/utils/UploadService';
import { compressImageToBuffer } from '../../core/utils/ImageCompressor';
import MD5 from '../../core/encryption/MD5';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { dataSharePredicates } from '@kit.ArkData';
import media from '@ohos.multimedia.media';
import image from '@ohos.multimedia.image';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';

const EMOJIS: string[] = ['😀','😁','😂','🤣','😊','😇','🙂','😉','😌','😍','🥰','😘','😗','😋','😛','😜','🤪','😝','🤑','🤗','🤭','🫣','🤫','🤔','🫡','🤐','🤨','😐','😑','😶','🫥','😏','😒','🙄','😬','😮','🤤','😴','😪','😵','🤐','🥴','😵‍💫','🤯','🤠','🥳','🥸','😎','🤓','🧐','😕','😟','🙁','😮','😯','😲','😳','🥺','😢','😭','😤','😡','🤬','💀','☠️','💩','🤡','👹','👺','👻','💀','☠️','👍','👎','👊','✊','🤛','🤜','👏','🙌','👐','🤲','🤝','🙏','✌️','🤞','🫰','🤟','🤘','🤙','👈','👉','👆','👇','🫵','👍🏻','👍🏼','👍🏽','👍🏾','👍🏿','💪','🤳','🫶','💋','❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💔','❣️','💕','💞','💗','💖','💘','💝','💟','🔥','⭐','🌟','✨','💫','🎉','🎊','🎈','🎁','🎀','🪄','💯','✅','❌','💢','💥','🛑','🚫','📛','🔞','💬','🗯️','💭','👁️','👀','🐶','🐱','🐭','🐹','🐰','🦊','🐻','🐼','🐨','🐯','🦁','🐮','🐷','🐸','🐵','🐔','🐧','🐦','🐤','🦆','🦅','🦉','🐍','🐢','🐸','🐳','🐬','🐟','🐠','🐡','🦈','🐙','🐚','🐌','🦋','🐛','🐜','🐝','🐞','🦗','🕷️','🦂','🌹','🌸','🌺','🌻','🌷','🌿','🍀','🌴','🌵','🌲','🌳','☘️','🍀','🍁','🍄','🌾','💐','🌸','🌼','🌻','🌞','🌝','🌚','🌛','🌜','☀️','🌤️','⛅','🌥️','🌦️','☁️','🌧️','⛈️','🌩️','🌨️','❄️','☃️','⛄','🌬️','💨','🌀','🌪️','🌫️','🌈','☂️','☔','⚡','🔥','💥','✨','🌟','⭐','🌍','🌎','🌏','🌐','🍏','🍎','🍐','🍊','🍋','🍌','🍉','🍇','🍓','🫐','🍈','🍒','🍑','🥭','🍍','🥥','🥝','🍅','🍆','🥑','🥦','🥬','🥒','🌶️','🌽','🥕','🧄','🧅','🥔','🍠','🥐','🍞','🥖','🥨','🧀','🥚','🍳','🥞','🧇','🥓','🥩','🍗','🍖','🌭','🍔','🍟','🍕','🫓','🥪','🥙','🧆','🌮','🌯','🥗','🥘','🫕','🥫','🍝','🍜','🍲','🍛','🍣','🍱','🥟','🦪','🍤','🍙','🍚','🍘','🍥','🥠','🥮','🍢','🍡','🍧','🍨','🍦','🍩','🍪','🎂','🍰','🧁','🥧','🍫','🍬','🍭','🍮','🍯','🍼','🥛','☕','🍵','🍶','🍺','🍻','🥂','🍷','🥃','🍸','🍹','🧉','🍾','🧊','🥄','🍴','🍽️','🥣','🥡','🥢','🧂'];

interface MediaItem {
  uri: string;
  type: 'image' | 'video';
  name: string;
  duration?: number;
  width?: number;
  height?: number;
  result?: UploadResult;
}

interface UploadResult {
  picId: string;
  width: string;
  height: string;
  videoId?: string;
  videoMd5?: string;
  videoUrl?: string;
  duration?: string;
  size?: string;
  thumbId?: string;
}

interface VideoMeta {
  durationMs: number;
  width: number;
  height: number;
}

interface ForumTabItem {
  tabId: number;
  tabName: string;
  tabType: number;
  isGeneralTab: number;
}

@Entry
@Component
struct NewThreadPage {
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  @StorageLink('fontScale') fontScale: number = 1.0;
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @State forumName: string = '';
  @State forumId: number = 0;
  @State title: string = '';
  @State content: string = '';
  @State submitting: boolean = false;
  @State showEmoji: boolean = false;
  @State selectedMedia: MediaItem[] = [];
  @State uploading: boolean = false;
  @State uploadProgress: number = -1;
  @State activeField: 'title' | 'content' = 'content';
  @State tabs: ForumTabItem[] = [];
  @State selectedTabId: number = 0;
  @State topicText: string = '';
  @State hotTopics: string[] = [];
  @State showTopicSuggest: boolean = false;

  aboutToAppear(): void {
    try { this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE); } catch (e) {}
    const params = router.getParams() as Record<string, string>;
    this.forumName = params?.forumName || '';
    this.forumId = parseInt(params?.forumId || '0');
    const rawTabs = params?.tabs || '';
    if (rawTabs) {
      try {
        const arr = JSON.parse(rawTabs) as ForumTabItem[];
        if (Array.isArray(arr)) this.tabs = arr;
      } catch (e) {}
    }
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
    void this.loadHotTopics();
  }

  private async loadHotTopics(): Promise<void> {
    try {
      const data: Dict = await HotTopicRepository.getInstance().loadTopicList();
      const names: string[] = [];
      const stack: Dict[] = [data];
      let guard = 0;
      while (stack.length > 0 && guard++ < 500) {
        const cur = stack.pop() as Dict;
        if (!cur || typeof cur !== 'object') continue;
        const n = String(cur.topicName || cur.topic_name || (cur.topic as Dict)?.topicName || (cur.topic as Dict)?.topic_name || '');
        if (n && n.length > 0 && names.indexOf(n) < 0 && names.length < 30) names.push(n);
        for (const k of Object.keys(cur)) {
          const v = cur[k];
          if (Array.isArray(v)) {
            for (const it of v as Dict[]) {
              if (it && typeof it === 'object') stack.push(it);
            }
          }
        }
      }
      console.info('TiebaLite: hotTopics=' + JSON.stringify(names));
      if (names.length === 0) {
        names.push('灌水', '求助', '经验分享', '原创', '盘点', '吐槽', '建议', '晒图');
      }
      this.hotTopics = names;
    } catch (e) {
      console.error('TiebaLite: loadHotTopics error=' + String(e));
    }
  }

  private suggestTopics(): string[] {
    const kw = this.topicText.replace(/#/g, '').trim();
    return this.hotTopics.filter((t: string) => kw.length === 0 || t.indexOf(kw) >= 0).slice(0, 6);
  }

  private onTopicInput(v: string): void {
    this.showTopicSuggest = v.indexOf('#') >= 0 || v.trim().length > 0;
  }

  private pickTopic(t: string): void {
    const existing = this.topicText.match(/#([^#]+)#/g) || [];
    for (const tag of existing) {
      if (tag.replace(/#/g, '') === t) {
        this.showTopicSuggest = false;
        return;
      }
    }
    const sep = this.topicText.trim().length > 0 ? ' ' : '';
    this.topicText = this.topicText + sep + '#' + t + '#';
    this.showTopicSuggest = false;
  }

  onIsDarkChange(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
  }

  onPageShow(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%').height('100%')
        .backgroundColor(blendWithBg(this.primaryColor, 0.05, this.isDark, '#1E1E1E'))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      Column() {
        Row() {
          Image($r('app.media.ic_arrow_back')).width(22).height(22).fillColor(textPrimary(this.isDark)).onClick(() => router.back())
          Text(this.forumName ? this.forumName + '吧' : '发布新帖').fontFamily(this.appFontFamily).fontSize(17).fontWeight(FontWeight.Bold)
            .fontColor(textPrimary(this.isDark)).margin({ left: 16 }).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Blank()
          if (this.uploading) {
            if (this.uploadProgress >= 0) {
              Text('上传中 ' + Math.round(this.uploadProgress) + '%').fontFamily(this.appFontFamily).fontSize(12).fontColor('#FF8C00').margin({ right: 8 })
            } else {
              LoadingProgress().width(18).height(18).margin({ right: 8 })
            }
          }
        }
        .padding({ left: 12, right: 12, top: 8, bottom: 8 }).width('100%')
        .backgroundColor(blendWithBg(this.primaryColor, 0.05, this.isDark, '#1E1E1E'))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        Scroll() {
          Column() {
            Row() {
              TextInput({ text: this.title, placeholder: '请输入标题' })
                .layoutWeight(1)
                .height(44)
                .backgroundColor(Color.Transparent).borderRadius(0)
                .padding({ left: 0, right: 0 })
                .maxLength(31)
                .fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
                .placeholderColor(textTertiary(this.isDark)).textAlign(TextAlign.Start)
                .onChange((v: string) => { this.title = v; })
                .onFocus(() => { this.activeField = 'title'; })
              Text(String(this.title.length) + '/31').fontFamily(this.appFontFamily).fontSize(12).fontColor(textSecondary(this.isDark)).margin({ left: 8 })
            }
            .width('100%').padding({ top: 2, bottom: 2 })

            Divider().height(0.5).color(dividerColor(this.isDark)).width('100%')

            Row() {
              TextArea({ text: this.content, placeholder: '写点什么吧' })
                .layoutWeight(1)
                .constraintSize({ minHeight: 220 })
                .backgroundColor(Color.Transparent).borderRadius(0)
                .padding({ left: 0, right: 8, top: 4 })
                .fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
                .placeholderColor(textTertiary(this.isDark)).textAlign(TextAlign.Start)
                .onChange((v: string) => { this.content = v; })
                .onFocus(() => { this.activeField = 'content'; })
              Text(String(this.content.length) + '/10000').fontFamily(this.appFontFamily).fontSize(12).fontColor(textSecondary(this.isDark)).margin({ top: 8 })
            }
            .width('100%').alignItems(VerticalAlign.Top)

            Divider().height(0.5).color(dividerColor(this.isDark)).width('100%')

            if (this.tabs.length > 0) {
              Row() {
                Text('分区').fontFamily(this.appFontFamily).fontSize(14).fontColor(textSecondary(this.isDark)).margin({ right: 8 })
                Scroll() {
                  Row() {
                    Text('默认分区')
                      .fontFamily(this.appFontFamily).fontSize(13)
                      .fontColor(this.selectedTabId === 0 ? '#FFFFFF' : textSecondary(this.isDark))
                      .backgroundColor(this.selectedTabId === 0 ? darkenColor(this.primaryColor, 0.15) : cardBg(this.isDark))
                      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                      .borderRadius(15).margin({ right: 8 })
                      .onClick(() => { this.selectedTabId = 0; })
                    ForEach(this.tabs, (t: ForumTabItem) => {
                      Text(t.tabName)
                        .fontFamily(this.appFontFamily).fontSize(13)
                        .fontColor(this.selectedTabId === t.tabId ? '#FFFFFF' : textSecondary(this.isDark))
                        .backgroundColor(this.selectedTabId === t.tabId ? darkenColor(this.primaryColor, 0.15) : cardBg(this.isDark))
                        .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                        .borderRadius(15).margin({ right: 8 })
                        .onClick(() => { this.selectedTabId = t.tabId; })
                    }, (t: ForumTabItem) => String(t.tabId))
                  }
                  .padding({ top: 6, bottom: 6 })
                }
                .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).layoutWeight(1)
              }
              .width('100%')
            }

            Divider().height(0.5).color(dividerColor(this.isDark)).width('100%')

            Row() {
              Text('话题').fontFamily(this.appFontFamily).fontSize(14).fontColor(textSecondary(this.isDark))
              TextInput({ text: this.topicText, placeholder: '输入 # 号添加话题' })
                .layoutWeight(1)
                .height(40)
                .margin({ left: 8 })
                .backgroundColor(Color.Transparent).borderRadius(0)
                .padding(0)
                .maxLength(80)
                .fontFamily(this.appFontFamily).fontSize(14).fontColor(textPrimary(this.isDark))
                .placeholderColor(textTertiary(this.isDark)).textAlign(TextAlign.Start)
                .onChange((v: string) => { this.topicText = v; this.onTopicInput(v); })
            }
            .width('100%').height(40)

            if (this.showTopicSuggest && this.suggestTopics().length > 0) {
              Column() {
                ForEach(this.suggestTopics(), (t: string, i: number) => {
                  Row() {
                    Text('#' + t + '#').fontFamily(this.appFontFamily).fontSize(14).fontColor(textPrimary(this.isDark))
                    Blank()
                    Text('添加').fontFamily(this.appFontFamily).fontSize(12).fontColor(textAccent(this.primaryColor, this.isDark))
                  }
                  .width('100%').height(40).padding({ left: 12, right: 12 })
                  .onClick(() => { this.pickTopic(t); })
                  if (i < this.suggestTopics().length - 1) {
                    Divider().height(0.5).color(dividerColor(this.isDark)).margin({ left: 12, right: 12 })
                  }
                }, (t: string) => t)
              }
              .width('100%').backgroundColor(cardBg(this.isDark)).borderRadius(8).margin({ top: 2 })
              .shadow({ radius: 8, color: shadowColor(this.isDark), offsetY: 4 })
            }

            Divider().height(0.5).color(dividerColor(this.isDark)).width('100%')

            if (this.selectedMedia.length > 0) {
              Scroll() {
                Row() {
                  ForEach(this.selectedMedia, (item: MediaItem, index: number) => {
                    Stack() {
                      if (item.type === 'image') {
                        Image(item.uri).width(96).height(96).borderRadius(8).objectFit(ImageFit.Cover)
                      } else {
                        Column() {
                          Image($r('app.media.ic_video')).width(36).height(36).fillColor('#FFFFFF')
                          Text(item.name).fontFamily(this.appFontFamily).fontSize(10).fontColor('#FFFFFF').maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis }).width(88).textAlign(TextAlign.Center).margin({ top: 4 })
                        }
                        .width(96).height(96).borderRadius(8).backgroundColor('rgba(0,0,0,0.4)')
                        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
                        if (item.duration && item.duration > 0) {
                          Text(this.formatDurationMs(item.duration))
                            .fontFamily(this.appFontFamily).fontSize(10).fontColor('#FFFFFF')
                            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                            .backgroundColor('#CC000000').borderRadius(3)
                            .position({ bottom: 3, right: 3 })
                        }
                      }
                      Stack() {
                        Text('×').fontFamily(this.appFontFamily).fontSize(13).fontColor('#666666').textAlign(TextAlign.Center)
                      }
                      .width(18).height(18).borderRadius(9).backgroundColor('#FFFFFF')
                      .position({ top: -5, right: -5 })
                      .shadow({ radius: 4, color: '#33000000', offsetY: 1 })
                    }
                    .width(96).height(100)
                    .onClick(() => {
                      this.selectedMedia.splice(index, 1);
                      this.selectedMedia = [...this.selectedMedia];
                    })
                    .margin({ right: 8 })
                  }, (item: MediaItem) => item.uri)
                }
                .width('100%').justifyContent(FlexAlign.Start)
                .padding({ top: 12, bottom: 4 })
              }
                .scrollBar(BarState.Off)
              .height(116)
            }

            if (this.showEmoji) {
              Scroll() {
                Grid() {
                  ForEach(EMOJIS, (emoji: string) => {
                    GridItem() {
                      Text(emoji).fontFamily(this.appFontFamily).fontSize(24).textAlign(TextAlign.Center).width('100%').height(40)
                    }
                    .onClick(() => {
                      this.content += emoji;
                    })
                  })
                }
                .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
                .width('100%').padding(4)
                .backgroundColor(cardBg(this.isDark))
                .borderRadius(12)
              }
                .scrollBar(BarState.Off)
              .height(200).width('100%')
            }
          }
          .width('100%').padding(16)
        }
          .scrollBar(BarState.Off)
          .align(Alignment.TopStart)
        .layoutWeight(1).width('100%')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])

        Row() {
          Image($r('app.media.ic_emoji')).width(24).height(24)
            .fillColor(this.showEmoji ? textAccent(this.primaryColor, this.isDark) : textSecondary(this.isDark))
            .onClick(() => { this.showEmoji = !this.showEmoji; })
          if (this.activeField !== 'title') {
            Image($r('app.media.ic_image_add')).width(24).height(24).fillColor(textSecondary(this.isDark)).margin({ left: 20 })
              .onClick(() => { this.pickMedia(); })
            Image($r('app.media.ic_video')).width(24).height(24).fillColor(textSecondary(this.isDark)).margin({ left: 20 })
              .onClick(() => { this.pickVideos(); })
          }
          Blank()
          Text('发布')
            .width(64).height(26).textAlign(TextAlign.Center)
            .backgroundColor(this.title.length > 0 && this.content.length > 0 && !this.uploading ? blendWithWhite(this.primaryColor, 0.35) : blendWithWhite(this.primaryColor, 0.25))
            .fontColor(this.title.length > 0 && this.content.length > 0 && !this.uploading ? '#0B2E6C' : '#8B96B4')
            .fontSize(15).fontWeight(FontWeight.Bold).borderRadius(12)
            .onClick(() => {
              if (this.title.length > 0 && this.content.length > 0 && !this.uploading && !this.submitting) {
                this.submitThread();
              }
            })
        }
        .width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .alignItems(VerticalAlign.Center)

        if (this.submitting) {
          Row() {
            LoadingProgress().width(16).height(16)
            Text('发布中...').fontFamily(this.appFontFamily).fontSize(13).fontColor(textTertiary(this.isDark)).margin({ left: 6 })
          }
          .width('100%').justifyContent(FlexAlign.Center).padding({ top: 10, bottom: 2 })
        }

        Text('根据相关法律法规，请勿发布违规内容')
          .fontFamily(this.appFontFamily).fontSize(12).fontColor('#FF4444').width('100%').textAlign(TextAlign.Center).padding({ top: 4, bottom: 14 })
      }.width('100%').height('100%').justifyContent(FlexAlign.Start).backgroundColor(blendWithBg(this.primaryColor, 0.05, this.isDark, '#1E1E1E'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .width('100%').height('100%').backgroundColor(pageBg(this.isDark)).expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    
  }

  private async pickMedia(): Promise<void> {
    try {
      const photoPicker = new picker.PhotoViewPicker();
      const result = await photoPicker.select({
        MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: Math.max(0, 9 - this.selectedMedia.length)
      });
      if (result.photoUris && result.photoUris.length > 0) {
        const newMedia: MediaItem[] = [];
        for (const uri of result.photoUris) {
          const p = await this.copyToSandbox(uri, 'image');
          if (p) {
            newMedia.push({ uri: p, type: 'image', name: uri.substring(uri.lastIndexOf('/') + 1) || 'image.jpg' });
          }
        }
        if (newMedia.length > 0) {
          this.selectedMedia = [...this.selectedMedia, ...newMedia];
          await this.uploadMedia(newMedia);
        }
      }
    } catch (e) {
      console.error('TiebaLite: pickMedia error=' + String(e));
    }
  }

  private async pickVideos(): Promise<void> {
    try {
      const photoPicker = new picker.PhotoViewPicker();
      const result = await photoPicker.select({
        MIMEType: picker.PhotoViewMIMETypes.VIDEO_TYPE,
        maxSelectNumber: Math.max(0, 4 - this.selectedMedia.filter(m => m.type === 'video').length)
      });
      if (result.photoUris && result.photoUris.length > 0) {
        const newMedia: MediaItem[] = [];
        for (const uri of result.photoUris) {
          const meta = await this.queryVideoMeta(uri);
          const p = await this.copyToSandbox(uri, 'video');
          if (p) {
            newMedia.push({ uri: p, type: 'video', name: uri.substring(uri.lastIndexOf('/') + 1) || 'video.mp4', duration: meta.durationMs, width: meta.width, height: meta.height });
          }
        }
        if (newMedia.length > 0) {
          this.selectedMedia = [...this.selectedMedia, ...newMedia];
          await this.uploadMedia(newMedia);
        }
      }
    } catch (e) {
      console.error('TiebaLite: pickVideos error=' + String(e));
    }
  }

  private async queryVideoMeta(uri: string): Promise<VideoMeta> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const ph = photoAccessHelper.getPhotoAccessHelper(context);
      const predicates = new dataSharePredicates.DataSharePredicates();
      predicates.equalTo('uri', uri);
      const fetchResult = await (ph.getAssets({
        fetchColumns: [photoAccessHelper.PhotoKeys.URI, photoAccessHelper.PhotoKeys.DURATION, photoAccessHelper.PhotoKeys.WIDTH, photoAccessHelper.PhotoKeys.HEIGHT],
        predicates: predicates
      }) as Promise<photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset>>);
      const asset = await (fetchResult.getFirstObject() as Promise<photoAccessHelper.PhotoAsset | undefined>);
      let durationMs = 0;
      let width = 0;
      let height = 0;
      if (asset) {
        try {
          let d = Number(asset.get(photoAccessHelper.PhotoKeys.DURATION) || 0);
          if (d > 0 && d < 600) d *= 1000;
          durationMs = Math.round(d);
        } catch (e) {}
        try { width = Number(asset.get(photoAccessHelper.PhotoKeys.WIDTH) || 0); } catch (e) {}
        try { height = Number(asset.get(photoAccessHelper.PhotoKeys.HEIGHT) || 0); } catch (e) {}
      }
      console.info('TiebaLite: video meta durMs=' + String(durationMs) + ' w=' + String(width) + ' h=' + String(height));
      return { durationMs: durationMs, width: width, height: height };
    } catch (e) {
      console.error('TiebaLite: queryVideoMeta error=' + String(e));
      return { durationMs: 0, width: 0, height: 0 };
    }
  }

  private async copyToSandbox(uri: string, kind: 'image' | 'video'): Promise<string> {
    try {
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(uri);
      if (stat.size <= 0) {
        try { fs.closeSync(file); } catch (e) {}
        return '';
      }
      const ctx = getContext(this) as common.UIAbilityContext;
      const dest = ctx.cacheDir + '/post_' + Date.now() + '_' + Math.floor(Math.random() * 100000) + (kind === 'video' ? '.mp4' : '.jpg');
      const out = fs.openSync(dest, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      const chunk = new ArrayBuffer(256 * 1024);
      let total = 0;
      while (total < stat.size) {
        const n = fs.readSync(file.fd, chunk, { offset: total, length: Math.min(chunk.byteLength, stat.size - total) });
        if (n <= 0) break;
        fs.writeSync(out.fd, chunk.slice(0, n));
        total += n;
      }
      fs.closeSync(out);
      fs.closeSync(file);
      console.info('TiebaLite: copied ' + kind + ' ' + total + ' bytes');
      return 'file://' + dest;
    } catch (e) {
      console.error('TiebaLite: copyToSandbox error=' + String(e));
      return '';
    }
  }

  private async uploadMedia(items: MediaItem[]): Promise<void> {
    this.uploading = true;
    this.uploadProgress = -1;
    const account = AccountManager.getInstance().getCurrentAccountSync();
    if (!account) {
      promptAction.showToast({ message: '未登录', duration: 1500 });
      this.uploading = false;
      return;
    }
    let failed = 0;
    try {
      for (const item of items) {
        let result: UploadResult | null = null;
        if (item.type === 'image') {
          result = await this.uploadImageToTieba(item.uri, item.name, account);
        } else if (item.type === 'video') {
          result = await this.uploadVideoToTieba(item.uri, item);
        }
        if (result) {
          const idx = this.selectedMedia.findIndex(m => m === item);
          if (idx >= 0) {
            this.selectedMedia[idx] = { uri: item.uri, type: item.type, name: item.name, result: result };
            this.selectedMedia = [...this.selectedMedia];
          }
        } else {
          failed++;
        }
      }
      if (items.length - failed > 0) {
        promptAction.showToast({ message: '媒体上传完成', duration: 1500 });
      }
      if (failed > 0) {
        promptAction.showToast({ message: failed + ' 项上传失败', duration: 2000 });
      }
    } catch (e) {
      console.error('TiebaLite: uploadMedia error=' + String(e));
    } finally {
      this.uploading = false;
    }
  }

  private async uploadImageToTieba(uri: string, fileName: string, account: Account): Promise<UploadResult | null> {
    try {
      const compressed = await compressImageToBuffer(uri);
      const buf = compressed.buffer;
      if (buf.byteLength <= 0) {
        console.error('TiebaLite: uploadImageToTieba empty after compress');
        return null;
      }
      const md5 = await MD5.hashBytes(new Uint8Array(buf));
      const raw = await uploadChunked('https://c.tieba.baidu.com/c/s/uploadPicture', buf, {
        fileName: fileName,
        mime: 'image/jpeg',
        groupId: '1',
        picWaterType: '0',
        forumName: this.forumName,
        resourceId: md5,
        width: String(compressed.width),
        height: String(compressed.height)
      });
      if (!raw) {
        console.error('TiebaLite: uploadImageToTieba no response');
        return null;
      }
      const errCode = raw.error_code || raw.errorCode || raw.no || '0';
      if (String(errCode) !== '0' && String(errCode) !== '300000') {
        console.error('TiebaLite: uploadImageToTieba failed code=' + errCode + ' result=' + JSON.stringify(raw).substring(0, 200));
        return null;
      }
      const info = (raw.info || raw.pic_info || raw.picInfo || raw.data) as Record<string, Object> || ({} as Record<string, Object>);
      const bigPic = (info.big_pic || info.bigPic || info.origin_pic || info.originPic) as Record<string, Object> || ({} as Record<string, Object>);
      const picId = String(raw.pic_id || raw.picId || raw.resource_id || raw.resourceId || info.pic_id || info.picId || '');
      if (picId) {
        return {
          picId: picId,
          width: String(bigPic.width || info.fullpic_width || info.width || compressed.width),
          height: String(bigPic.height || info.fullpic_height || info.height || compressed.height)
        };
      }
      console.error('TiebaLite: uploadImageToTieba no pic_id result=' + JSON.stringify(raw).substring(0, 200));
      return null;
    } catch (e) {
      console.error('TiebaLite: uploadImageToTieba error=' + String(e));
      return null;
    }
  }

  private async uploadVideoToTieba(uri: string, item: MediaItem): Promise<UploadResult | null> {
    console.info('TiebaLite: video upload start uri=' + uri);
    try {
      const stat = fs.statSync(uri);
      const durationMs = item.duration || 0;
      const width = item.width || 0;
      const height = item.height || 0;
      console.info('TiebaLite: video size=' + String(stat.size) + ' durMs=' + String(durationMs) + ' w=' + String(width) + ' h=' + String(height));
      const result = await uploadVideoToTieba(uri, { durationMs: durationMs, onProgress: (p) => { this.uploadProgress = p; } });
      if (!result) {
        console.error('TiebaLite: uploadVideoToTieba failed');
        return null;
      }
      console.info('TiebaLite: video upload done url=' + result.videoUrl + ' md5=' + result.videoMd5);
      let thumbId = '';
      try {
        const thumbBuf = await this.generateVideoThumb(uri);
        if (thumbBuf && thumbBuf.byteLength > 0) {
          const ctx = getContext(this) as common.UIAbilityContext;
          const thumbPath = ctx.cacheDir + '/thumb_' + Date.now() + '.jpg';
          const out = fs.openSync(thumbPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
          fs.writeSync(out.fd, thumbBuf);
          fs.closeSync(out);
          const account = AccountManager.getInstance().getCurrentAccountSync();
          if (account) {
            const thumbResult = await this.uploadImageToTieba('file://' + thumbPath, 'thumb.jpg', account);
            if (thumbResult && thumbResult.picId) {
              thumbId = thumbResult.picId;
              console.info('TiebaLite: video thumb uploaded picId=' + thumbId);
            }
          }
        }
      } catch (e) {
        console.error('TiebaLite: video thumb upload error=' + String(e));
      }
      return { picId: '', width: String(width), height: String(height), videoMd5: result.videoMd5, videoUrl: result.videoUrl, duration: String(durationMs), size: String(stat.size), thumbId: thumbId };
    } catch (e) {
      console.error('TiebaLite: uploadVideoToTieba error=' + String(e));
      return null;
    }
  }

  private async generateVideoThumb(uri: string): Promise<ArrayBuffer | null> {
    try {
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const generator = await media.createAVImageGenerator();
      generator.fdSrc = { fd: file.fd, offset: 0, length: -1 };
      const pixelMap = await generator.fetchFrameByTime(0, media.AVImageQueryOptions.AV_IMAGE_QUERY_CLOSEST_SYNC, { width: 480 });
      const packer = image.createImagePacker();
      const buf = await packer.packing(pixelMap, { format: 'image/jpeg', quality: 85 });
      await packer.release();
      await pixelMap.release();
      await generator.release();
      fs.closeSync(file);
      console.info('TiebaLite: video thumb generated bytes=' + String(buf.byteLength));
      return buf;
    } catch (e) {
      console.error('TiebaLite: generateVideoThumb error=' + String(e));
      return null;
    }
  }

  private formatDurationMs(d: number): string {
    const s = Math.floor(d / 1000);
    const m = Math.floor(s / 60);
    const sec = s % 60;
    return m > 0 ? m + ':' + (sec < 10 ? '0' : '') + sec : '0:' + (sec < 10 ? '0' : '') + sec;
  }

  private async submitThread(): Promise<void> {
    if (this.submitting) return;
    if (!AccountManager.getInstance().isLoggedIn()) {
      NavigationHelper.navigate('pages/login/LoginPage'); return;
    }
    this.submitting = true;
    try {
      let fullContent = this.content;
      const topics: string[] = [];
      const topicTags = this.topicText.match(/#([^#]+)#/g) || [];
      for (const tag of topicTags) {
        const n = tag.replace(/#/g, '').trim();
        if (n.length > 0 && topics.indexOf(n) < 0) topics.push(n);
      }
      if (topics.length > 0) {
        fullContent = topics.map(t => '#' + t + '#').join(' ') + '\n' + fullContent;
      }
      for (const item of this.selectedMedia) {
        if (!item.result) continue;
        if (item.result.videoUrl && item.result.videoMd5) {
          const w = item.result.width || '0';
          const h = item.result.height || '0';
          const dur = item.result.duration || '0';
          const len = item.result.size || '0';
          const thumb = item.result.thumbId || '';
          fullContent += '\n#(movideo,' + thumb + ',' + w + ',' + h + ',' + item.result.videoMd5 + ',' + item.result.videoUrl + ',' + dur + ',' + w + ',' + h + ',' + len + ',2)';
        } else if (item.result.picId) {
          fullContent += '\n#(pic,' + item.result.picId + ',' + item.result.width + ',' + item.result.height + ')';
        }
      }
      await AddPostRepository.getInstance().createThread(this.forumName, this.forumId, this.title, fullContent, this.selectedTabId);
      promptAction.showToast({ message: '发布成功', duration: 2000 });
      NavigationHelper.back();
    } catch (e) {
      console.error('TiebaLite: createThread error=' + String(e));
      promptAction.showToast({ message: '发布失败请重试', duration: 2000 });
    } finally {
      this.submitting = false;
    }
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
      } else {
        PageTransitionEnter({ duration: 300, curve: Curve.FastOutSlowIn })
          .opacity(0)
        PageTransitionExit({ duration: 300, curve: Curve.FastOutSlowIn })
          .opacity(0)
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
