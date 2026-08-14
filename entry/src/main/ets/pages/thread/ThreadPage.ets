import router from '@ohos.router';
import Window from '@ohos.window';
import { KeyboardAvoidMode } from '@ohos.arkui.UIContext';
import display from '@ohos.display';
import inputMethod from '@ohos.inputMethod';
import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard';
import http from '@ohos.net.http';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';

import common from '@ohos.app.ability.common';
import webview from '@ohos.web.webview';
import PbPageRepository from '../../core/repository/PbPageRepository';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import AddPostRepository from '../../core/repository/AddPostRepository';
import ThreadStoreRepository from '../../core/repository/ThreadStoreRepository';
import HistoryRepository from '../../core/repository/HistoryRepository';
import AccountManager from '../../core/auth/AccountManager';
import BlockRepository from '../../core/repository/BlockRepository';
import PreferencesManager from '../../core/storage/PreferencesManager';
import DeviceFingerprint from '../../core/device/DeviceFingerprint';
import PbContentRender from '../../components/PbContentRender';
import ThreadImageFetcher, { PhotoUrlCache, ThreadImageCollectResult } from '../../core/utils/ThreadImageFetcher';
import ThreadCard from '../../components/ThreadCard';
import LoadingState from '../../components/LoadingState';
import ErrorState from '../../components/ErrorState';
import Avatar from '../../components/Avatar';
import GearLoading from '../../components/GearLoading';
import GearCycle from '../../components/GearCycle';
import PullToRefresh from '../../components/PullToRefresh';
import NetworkImage from '../../components/Images';
import { Dict } from '../../core/types/Dict';
import { buildPortraitUrl, getStr, blendWithWhite, blendWithBg, darkenColor, textAccent, pageBg, cardBg, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor, KEYBOARD_IME_EXTRA_VP, withAlpha, primaryContainer, onPrimaryContainer } from '../../core/utils/DataHelper';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';
import { uploadChunked } from '../../core/utils/UploadService';
import { compressImageToBuffer } from '../../core/utils/ImageCompressor';
import MD5 from '../../core/encryption/MD5';
import { GripDetector } from '../../core/utils/GripDetector';
import { richEditorToText } from '../../components/EmojiManager';

class ImageUploadResult {
  picId: string = '';
  width: string = '';
  height: string = '';
}

class PostPosInfo {
  y: number = 0;
  h: number = 0;
}

class EmojiItem {
  id: string;
  name: string;
  constructor(id: string, name: string) {
    this.id = id;
    this.name = name;
  }
}

const EMOTICONS: EmojiItem[] = [
  new EmojiItem('image_emoticon1', 'Smile'), new EmojiItem('image_emoticon2', 'LOL'),
  new EmojiItem('image_emoticon3', 'Tongue'), new EmojiItem('image_emoticon4', 'Kiss'),
  new EmojiItem('image_emoticon5', 'Cool'), new EmojiItem('image_emoticon6', 'Puzzled'),
  new EmojiItem('image_emoticon7', 'Happy'), new EmojiItem('image_emoticon8', 'Sweat'),
  new EmojiItem('image_emoticon9', 'Tears'), new EmojiItem('image_emoticon10', 'Blackline'),
  new EmojiItem('image_emoticon11', 'Despise'), new EmojiItem('image_emoticon12', 'Unhappy'),
  new EmojiItem('image_emoticon13', 'Shy'), new EmojiItem('image_emoticon14', 'Angry'),
  new EmojiItem('image_emoticon15', 'Question'), new EmojiItem('image_emoticon16', 'Sly'),
  new EmojiItem('image_emoticon17', 'Bite'), new EmojiItem('image_emoticon18', 'Cat'),
  new EmojiItem('image_emoticon19', 'Wronged'), new EmojiItem('image_emoticon20', 'Playboy'),
  new EmojiItem('image_emoticon21', 'Phew'), new EmojiItem('image_emoticon22', 'Laughing Eyes'),
  new EmojiItem('image_emoticon23', 'Cold'), new EmojiItem('image_emoticon24', 'Overjoyed'),
  new EmojiItem('image_emoticon25', 'Slick'), new EmojiItem('image_emoticon26', 'Reluctant'),
  new EmojiItem('image_emoticon27', 'Crazy Sweat'), new EmojiItem('image_emoticon28', 'Dizzy'),
  new EmojiItem('image_emoticon29', 'Sleepy'), new EmojiItem('image_emoticon30', 'Cry'),
  new EmojiItem('image_emoticon31', 'Angry'), new EmojiItem('image_emoticon32', 'Shocked'),
  new EmojiItem('image_emoticon33', 'Drink'), new EmojiItem('image_emoticon34', 'Heart'),
  new EmojiItem('image_emoticon35', 'Broken Heart'), new EmojiItem('image_emoticon36', 'Rose'),
  new EmojiItem('image_emoticon37', 'Gift'), new EmojiItem('image_emoticon38', 'Rainbow'),
  new EmojiItem('image_emoticon39', 'Star Moon'), new EmojiItem('image_emoticon40', 'Sun'),
  new EmojiItem('image_emoticon41', 'Money'), new EmojiItem('image_emoticon42', 'Bubble'),
  new EmojiItem('image_emoticon43', 'Tea'), new EmojiItem('image_emoticon44', 'Cake'),
  new EmojiItem('image_emoticon45', 'Music'), new EmojiItem('image_emoticon46', 'haha'),
  new EmojiItem('image_emoticon47', 'Victory'), new EmojiItem('image_emoticon48', 'Thumb Up'),
  new EmojiItem('image_emoticon49', 'Open'), new EmojiItem('image_emoticon50', 'OK'),
  new EmojiItem('image_emoticon77', 'Sofa'), new EmojiItem('image_emoticon78', 'Tissue'),
  new EmojiItem('image_emoticon79', 'Banana'), new EmojiItem('image_emoticon80', 'Poop'),
  new EmojiItem('image_emoticon81', 'Pill'), new EmojiItem('image_emoticon82', 'Bow Tie'),
  new EmojiItem('image_emoticon83', 'Candle'), new EmojiItem('image_emoticon84', 'Three Lines'),
  new EmojiItem('shoubai_emoji1', 'Bye'), new EmojiItem('shoubai_emoji2', 'Hug'),
  new EmojiItem('shoubai_emoji3', 'Speechless'), new EmojiItem('shoubai_emoji4', 'Sour'),
  new EmojiItem('shoubai_emoji5', 'Impressive'), new EmojiItem('shoubai_emoji6', 'Eating Melon'),
  new EmojiItem('shoubai_emoji7', 'Dog Head'), new EmojiItem('shoubai_emoji8', 'Like'),
  new EmojiItem('shoubai_emoji9', 'Heart Hands'), new EmojiItem('shoubai_emoji10', 'Call'),
  new EmojiItem('shoubai_emoji11', 'Hit'), new EmojiItem('shoubai_emoji12', 'Look Around'),
  new EmojiItem('shoubai_emoji13', 'Peek'), new EmojiItem('shoubai_emoji14', 'doge'),
  new EmojiItem('shoubai_emoji15', 'Smirk'), new EmojiItem('shoubai_emoji16', 'Sigh'),
  new EmojiItem('shoubai_emoji17', 'Scared'), new EmojiItem('shoubai_emoji18', 'Tired'),
  new EmojiItem('shoubai_emoji19', 'Pick Nose'), new EmojiItem('shoubai_emoji20', 'Black Face'),
  new EmojiItem('image_emoticon61', 'Confused'), new EmojiItem('image_emoticon62', 'Grin'),
  new EmojiItem('image_emoticon63', 'Cute'), new EmojiItem('image_emoticon64', 'Shy'),
  new EmojiItem('image_emoticon65', 'Color'), new EmojiItem('image_emoticon66', 'Shy'),
  new EmojiItem('image_emoticon67', 'Tear Stream'), new EmojiItem('image_emoticon68', 'Awkward'),
  new EmojiItem('image_emoticon69', 'Sunny'), new EmojiItem('image_emoticon70', 'Crazy'),
  new EmojiItem('image_emoticon71', 'Pick Nose'), new EmojiItem('image_emoticon72', 'Clap'),
  new EmojiItem('image_emoticon73', 'Right Pout'), new EmojiItem('image_emoticon74', 'Left Pout'),
  new EmojiItem('image_emoticon75', 'Kiss'), new EmojiItem('image_emoticon76', 'Wronged'),
  new EmojiItem('image_emoticon85', 'Pick Nose'), new EmojiItem('image_emoticon86', 'Clap'),
  new EmojiItem('image_emoticon87', 'Rich Man'), new EmojiItem('image_emoticon88', 'Grin'),
  new EmojiItem('image_emoticon89', 'Sigh'), new EmojiItem('image_emoticon90', 'Kiss'),
  new EmojiItem('image_emoticon91', 'Pitiful'), new EmojiItem('image_emoticon92', 'Knife'),
  new EmojiItem('image_emoticon93', 'Melon'), new EmojiItem('image_emoticon94', 'Beer'),
  new EmojiItem('image_emoticon95', 'Basketball'), new EmojiItem('image_emoticon96', 'Table Tennis'),
  new EmojiItem('image_emoticon97', 'Coffee'), new EmojiItem('image_emoticon98', 'Rice'),
  new EmojiItem('image_emoticon99', 'Pig Head'), new EmojiItem('image_emoticon100', 'Fresh Flower'),
  new EmojiItem('image_emoticon101', 'Gift'),
  new EmojiItem('image_emoticon125', 'Struggle'), new EmojiItem('image_emoticon126', 'Fight On'),
  new EmojiItem('image_emoticon127', 'Hug'), new EmojiItem('image_emoticon128', 'Kneel'),
  new EmojiItem('image_emoticon129', 'Cheers'), new EmojiItem('image_emoticon130', 'Excellent'),
  new EmojiItem('image_emoticon131', 'Eye'), new EmojiItem('image_emoticon132', 'Kiss'),
  new EmojiItem('image_emoticon133', '666'), new EmojiItem('image_emoticon134', 'Flash'),
  new EmojiItem('image_emoticon135', 'Think'), new EmojiItem('image_emoticon136', 'Agree'),
  new EmojiItem('image_emoticon137', 'Oppose')
];

function emojiUrl(id: string): string {
  return 'http://static.tieba.baidu.com/tb/editor/images/client/' + id + '.png';
}

@Entry
@Component
struct ThreadPage {
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  @StorageLink('secondaryColor') secondaryColor: string = '#575E71';
  @StorageLink('tertiaryColor') tertiaryColor: string = '#5F5791';
  @StorageLink('gripSide') @Watch('onGripSideChanged') gripSide: number = 0;
  @StorageLink('fabRadius') fabRadius: number = 60;
  reduceEffects: boolean = false;
  @StorageLink('fontScale') fontScale: number = 1.06;
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('headerAlpha') headerAlpha: number = 25;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @StorageProp('hideOnScroll') hideOnScroll: boolean = true;
  @State threadId: number = 0;
  @State forumId: number = 0;
  @State forumName: string = '';
  @State forumAvatar: string = '';
  @State seeLz: boolean = false;
  @State sortType: number = 0;

  @State threadData: Dict | null = null;
  @State posts: Dict[] = [];
  @State allThreadImageUrls: string[] = [];
  @State page: number = 1;
  @State totalPage: number = 0;
  @State hasMore: boolean = true;
  @State loadingMore: boolean = false;
  @State loading: boolean = true;
  @State error: string = '';
  @State liked: boolean = false;
  @State likeCount: number = 0;
  @State collectCount: number = 0;
  @State showMenu: boolean = false;
  @State showJump: boolean = false;
  @State jumpPageText: string = '';
  @State scrollTop: number = 0;
  @State isCollected: boolean = false;
  @State immersiveMode: boolean = false;
  @State replyText: string = '';
  @State showReply: boolean = false;
  @State showRiskWarning: boolean = false;
  @State riskNeverAgainChecked: boolean = false;
  @State agreeToRisk: boolean = false;
  @State showEmojiPanel: boolean = false;
  @State selectedImageUris: string[] = [];
  @State imageUploadResults: ImageUploadResult[] = [];
  @State uploadingImages: boolean = false;
  @State replyContent: string = '';
  private richController: RichEditorController = new RichEditorController();
  @State showFixedBar: boolean = false;
  @State showForumBar: boolean = true;
  @State headerH: number = 56;
  @State showBottomBar: boolean = true;
  @State showScrollTop: boolean = false;
  @State lastScrollY: number = 0;
  @State fabLeft: boolean = false;
  private fabTimer: number = -1;
  @State replyHint: string = '';
  @State replyPostId: number = 0;
  @State replyUserId: number = 0;
  @State keyboardHeight: number = 0;
  @State kbExtra: number = AppStorage.Get<number>('replyKbExtraV2') ?? KEYBOARD_IME_EXTRA_VP;
  @State replyEditorH: number = 46;
  @State menuShow: boolean = false;
  @State menuPostId: number = 0;
  @State menuPostAuthorId: number = 0;
  @State menuText: string = '';
  @State menuX: number = 0;
  @State menuY: number = 0;
  @State screenWidth: number = 360;
  @State screenHeight: number = 800;
  @State topInset: number = 24;
  @State isThreadAuthor: boolean = false;
  private contentAboveHeight: number = 0;
  @State barWidth: number = 0;
  @State touchX: number = 0;
  @State touchY: number = 0;
  @State liquidR: number = 0;
  @State liquidAlpha: number = 0;
  private liquidCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D();

  @State @Watch('onIsRefreshingChange') isRefreshing: boolean = false;

  private scroller: Scroller = new Scroller();
  private repo: PbPageRepository = PbPageRepository.getInstance();
  private _photosPrefetched: boolean = false;
  private _allImagePidOrder: number[] = [];
  private _allImagePidCounts: Map<number, number> = new Map();
  private _win: Window.Window | null = null;
  private _density: number = 1;
  private _winH0: number = 0;
  private _winGapVp: number = 0;
  private _lastKbHpx: number = 0;
  private _kbAdjustAt: number = 0;
  private _userMap: Map<number, Dict> = new Map();
  private _managerIds: Set<number> = new Set();
  private _bazhuIds: Set<number> = new Set();
  private _firstPostId: number = 0;
  private _postPosMap: Map<number, PostPosInfo> = new Map();
  private replyPanelH: number = 180;
  private _replyScrollTimer: number = -1;

  private initTopInset(): void {
    try {
      Window.getLastWindow(getContext(this)).then((win: Window.Window) => {
        const avoidArea = win.getWindowAvoidArea(Window.AvoidAreaType.TYPE_SYSTEM);
        if (avoidArea.topRect.height > 0) {
          const density = display.getDefaultDisplaySync().densityPixels;
          this.topInset = Math.max(20, Math.round(avoidArea.topRect.height / density));
        }
      }).catch(() => { });
    } catch (e) {
      console.warn('TiebaLite: ThreadPage initTopInset failed ' + JSON.stringify(e));
    }
  }

  aboutToAppear(): void {
    try { this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE); } catch (e) {}
    console.info('TiebaLite: [C1] ThreadPage aboutToAppear');
    this.initTopInset();
    try {
      const params = router.getParams() as Record<string, string>;
      console.info('TiebaLite: [C2] params=' + JSON.stringify(params));
      this.threadId = parseInt(params?.threadId || '0');
      this.forumId = parseInt(params?.forumId || '0');
      this.forumName = params?.forumName || '';
      if (params?.isCollected === '1' || params?.isCollected === 'true') this.isCollected = true;
      const displayInfo = display.getDefaultDisplaySync();
      this.screenWidth = displayInfo.width / displayInfo.densityPixels;
      this.screenHeight = displayInfo.height / displayInfo.densityPixels;
      this._density = displayInfo.densityPixels;
      PreferencesManager.getInstance().getInt('replyKbExtraV2', KEYBOARD_IME_EXTRA_VP).then((v: number) => {
        if (v > 0 && v !== this.kbExtra) {
          this.kbExtra = v;
          AppStorage.SetOrCreate('replyKbExtraV2', v);
        }
      }).catch(() => {});
      void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
      void BlockRepository.getInstance().ensureLoaded();
      this.onGripSideChanged();
      this.loadThread(1);
    } catch (e) {
      console.error('TiebaLite: [CERR] ThreadPage aboutToAppear error=' + String(e));
    }
  }

  onIsDarkChange(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
  }

  onIsRefreshingChange(): void {
    if (this.isRefreshing) {
      void this.loadThread(this.page, true).finally(() => {
        this.isRefreshing = false;
      });
    }
  }

  onPageShow(): void {
    AppStorage.SetOrCreate('previewActiveId', '');
    AppStorage.SetOrCreate('previewActiveVisible', false);
    const t = AppStorage.get<number>('previewClaimTick') || 0;
    AppStorage.SetOrCreate<number>('previewClaimTick', t + 1);
    const sv = AppStorage.get<number>('pageShowTick') || 0;
    AppStorage.SetOrCreate('pageShowTick', sv + 1);
    this.reduceEffects = AppStorage.get<boolean>('reduceEffects') === true;
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
    this.bindKeyboardListener();
  }

  onPageHide(): void {
    AppStorage.SetOrCreate('previewActiveId', '');
    AppStorage.SetOrCreate('previewActiveVisible', false);
    const hv = AppStorage.get<number>('pageHideTick') || 0;
    AppStorage.SetOrCreate('pageHideTick', hv + 1);
    this.unbindKeyboardListener();
  }

  private bindKeyboardListener(): void {
    try {
      Window.getLastWindow(getContext(this)).then((win: Window.Window) => {
        try { win.off('keyboardHeightChange'); win.off('avoidAreaChange'); win.off('keyboardWillShow'); win.off('keyboardDidShow'); win.off('keyboardDidHide'); } catch (_e) {}
        this._win = win;
        try {
          this._winH0 = win.getWindowProperties().windowRect.height;
          this._winGapVp = Math.max(0, this.screenHeight - this._winH0 / this._density);
        } catch (_e) {}
        console.info('TiebaLite: kb win0px=' + this._winH0 + ' dispHvp=' + this.screenHeight.toFixed(1) + ' winGapVp=' + this._winGapVp.toFixed(1));
        const readKbAvoidHpx = (): number => {
          try {
            const area = win.getWindowAvoidArea(Window.AvoidAreaType.TYPE_KEYBOARD);
            return area && area.bottomRect ? Number(area.bottomRect.height || 0) : 0;
          } catch (_e) { return 0; }
        };
        const applyKbTop = (topPx: number): void => {
          try {
            const winH = win.getWindowProperties().windowRect.height;
            const avoidHpx = readKbAvoidHpx();
            const kbCorr = 30;
            let off = winH / this._density - topPx / this._density - this.kbExtra;
            if (avoidHpx > 0) {
              off = avoidHpx / this._density - this.kbExtra - kbCorr;
            } else {
              off -= kbCorr;
            }
            this.keyboardHeight = Math.max(0, off);
            console.info('TiebaLite: kb exact topPx=' + topPx + ' win=' + winH + ' avoidPx=' + avoidHpx + ' extra=' + this.kbExtra + ' corr=' + kbCorr + ' offset=' + this.keyboardHeight.toFixed(1));
            this.scheduleReplyScroll(300);
          } catch (_e) {}
        };
        const applyKbDelta = (hPx: number): void => {
          try {
            if (hPx <= 0) {
              this.keyboardHeight = 0;
              this._lastKbHpx = 0;
              this.scheduleReplyScroll(300);
              return;
            }
            const avoidHpx = readKbAvoidHpx();
            const kbCorr = 30;
            if (avoidHpx > 0) {
              this.keyboardHeight = Math.max(0, avoidHpx / this._density - this.kbExtra - kbCorr);
            } else if (this._lastKbHpx > 0 && this.keyboardHeight > 0) {
              this.keyboardHeight = Math.max(0, this.keyboardHeight + (this._lastKbHpx - hPx) / this._density);
            } else {
              this.keyboardHeight = Math.max(0, hPx / this._density - this._winGapVp - this.kbExtra - kbCorr);
            }
            this._lastKbHpx = hPx;
            console.info('TiebaLite: kb delta hPx=' + hPx + ' avoidPx=' + avoidHpx + ' extra=' + this.kbExtra + ' offset=' + this.keyboardHeight.toFixed(1));
            this.scheduleReplyScroll(300);
          } catch (_e) {}
        };
        const logKbInfo = (tag: string, info: Window.KeyboardInfo): void => {
          try {
            const b: Window.Rect | undefined = info?.beginRect;
            const r: Window.Rect | undefined = info?.endRect;
            console.info('TiebaLite: ' + tag + ' begin(h=' + (b ? (b.height / this._density).toFixed(1) : '?') + ' top=' + (b ? (b.top / this._density).toFixed(1) : '?') + ') end(h=' + (r ? (r.height / this._density).toFixed(1) : '?') + ' top=' + (r ? (r.top / this._density).toFixed(1) : '?') + ') endPx=' + (r ? r.height : -1) + ' dispHvp=' + this.screenHeight.toFixed(1));
          } catch (_e) {}
        };
        win.on('keyboardWillShow', (info: Window.KeyboardInfo): void => {
          logKbInfo('kbWillShow', info);
          try {
            const r: Window.Rect | undefined = info?.endRect;
            if (r && r.height > 0) {
              this._lastKbHpx = r.height;
              applyKbTop(r.top);
            }
          } catch (_e) {}
        });
        win.on('keyboardDidShow', (info: Window.KeyboardInfo): void => {
          logKbInfo('kbDidShow', info);
          try {
            const r: Window.Rect | undefined = info?.endRect;
            if (r && r.height > 0) {
              this._lastKbHpx = r.height;
              applyKbTop(r.top);
              if (this.showEmojiPanel) {
                this.showEmojiPanel = false;
                this.scheduleReplyScroll(300);
              }
            }
          } catch (_e) {}
        });
        win.on('keyboardDidHide', (info: Window.KeyboardInfo): void => {
          logKbInfo('kbDidHide', info);
          this._lastKbHpx = 0;
          this.keyboardHeight = 0;
          this.scheduleReplyScroll(300);
        });
        win.on('keyboardHeightChange', (h: number) => { applyKbDelta(h); });
        win.on('avoidAreaChange', () => {
          try {
            const area = win.getWindowAvoidArea(Window.AvoidAreaType.TYPE_KEYBOARD);
            applyKbDelta(area && area.bottomRect ? area.bottomRect.height : 0);
          } catch (_e) {}
        });
      }).catch(() => {})
    } catch (_e) {}
  }

  private unbindKeyboardListener(): void {
    try {
      if (this._win) {
        this._win.off('keyboardHeightChange');
        this._win.off('avoidAreaChange');
        this._win.off('keyboardWillShow');
        this._win.off('keyboardDidShow');
        this._win.off('keyboardDidHide');
        this._win = null;
      }
    } catch (_e) {}
  }

  private closeReplyWindow(): void {
    this.showReply = false;
    this.replyContent = '';
    this.richController.deleteSpans();
    this.selectedImageUris = [];
    this.imageUploadResults = [];
    this.showEmojiPanel = false;
    this.replyHint = '';
    this.replyPostId = 0;
    this.replyUserId = 0;
    try { inputMethod.getController().stopInputSession(); } catch (_e) {}
  }

  private async sendReply(): Promise<void> {
    if (this.uploadingImages) return;
    try {
      this.uploadingImages = true;
      let content = this.replyContent;
      if (this.selectedImageUris.length > 0) {
        this.imageUploadResults = [];
        for (const uri of this.selectedImageUris) {
          const picId = await this.uploadImageAndGetId(uri);
          if (picId) {
            let w = '0';
            let h = '0';
            const result = this.imageUploadResults.find(r => r.picId === picId);
            if (result) {
              w = result.width;
              h = result.height;
            }
            content += '\n#(pic,' + picId + ',' + w + ',' + h + ')';
          } else {
            promptAction.showToast({ message: '图片上传失败，已取消发送', duration: 2000 });
            return;
          }
        }
      }
      await AddPostRepository.getInstance().replyToThread(this.forumId, this.forumName, this.threadId, content, this.replyPostId > 0 ? this.replyPostId : undefined, undefined, this.replyUserId > 0 ? this.replyUserId : undefined);
      this.closeReplyWindow();
      this.repo.clearThreadCache();
      const page1Data = await this.repo.loadThreadPage(this.threadId, 1, this.seeLz, this.sortType);
      const pInfo = (page1Data.page as Dict) || (page1Data.data as Dict)?.page as Dict || {};
      const total = Number(pInfo.totalPage || pInfo.total_page || 0);
      const targetPage = this.sortType === 0 && total > 1 ? total : 1;
      await this.loadThread(targetPage);
    } catch (e) {
      console.error('TiebaLite: Reply failed:', e);
      promptAction.showToast({ message: '回复失败', duration: 2000 });
    } finally {
      this.uploadingImages = false;
    }
  }

  async loadThread(initialPage?: number, silent?: boolean): Promise<void> {
    console.info('TiebaLite: [D1] loadThread start page=' + (initialPage ?? 1) + ' sort=' + this.sortType);
    if (!silent) {
      this.loading = true;
      this.error = '';
    }
    try {
      if (!this.threadId || this.threadId <= 0) {
        console.info('TiebaLite: [D2] invalid threadId');
        if (!silent) { this.error = '无效的帖子ID'; }
        return;
      }
      const reqPage: number = initialPage || 1;
      console.info('TiebaLite: [D3] calling loadThreadPage');
      const data: Dict = await this.repo.loadThreadPage(this.threadId, reqPage, this.seeLz, this.sortType);
      console.info('TiebaLite: [D4] loadThreadPage returned data=' + (data ? 'ok' : 'null'));
      if (!data) { if (!silent) { this.error = '帖子数据为空'; } return; }
        try {
          const forumObj = data.forum as Dict;
          const rawPosts = data.post_list || (data.data as Dict)?.post_list || [];
          const firstPost: Dict = (Array.isArray(rawPosts) ? rawPosts as Dict[] : [])[0] as Dict || {};
          const forumIdCandidate = Number(data.forum_id || (data.data as Dict)?.forum_id || forumObj?.id || data.fid || (data.thread as Dict)?.forum_id || firstPost.forum_id || 0);
          if (forumIdCandidate > 0 && this.forumId === 0) this.forumId = forumIdCandidate;
          if (!this.forumName) this.forumName = getStr(data, 'forumName', 'forum_name', 'fname') || (forumObj ? getStr(forumObj, 'name', 'forumName', 'forum_name') : '');
          if (!this.forumAvatar) {
      this.forumAvatar = getStr(data, 'forumAvatar', 'forum_avatar', 'forumAvatarUrl', 'forum_avatar_url');
      if (!this.forumAvatar && forumObj) this.forumAvatar = getStr(forumObj, 'avatar', 'forumAvatar', 'forum_avatar', 'forumAvatarUrl', 'forum_avatar_url');
      if (!this.forumAvatar) {
        const rawPosts = data.post_list || (data.data as Dict)?.post_list || [];
        const firstPost: Dict = (Array.isArray(rawPosts) ? rawPosts as Dict[] : [])[0] as Dict || {};
        if (firstPost) this.forumAvatar = getStr(firstPost, 'forumAvatar', 'forum_avatar', 'forumAvatarUrl', 'forum_avatar_url');
      }
    }
          console.info('TiebaLite: [D4a] forum info extracted: id=' + this.forumId + ' name=' + this.forumName + ' avatar=' + this.forumAvatar);
        } catch (e) {
          console.error('TiebaLite: [D4a] forumId extraction error=' + String(e));
        }
        if (!this.forumAvatar) {
          const forumHead = data.forum as Dict || (data.data as Dict)?.forum as Dict || {};
          this.forumAvatar = getStr(forumHead, 'head', 'avatar', 'forum_avatar', 'avatarUrl', 'forumAvatarUrl', 'icon', 'img', 'picture');
          if (!this.forumAvatar) {
            const forumInfo = data.forum_info as Dict || (data.data as Dict)?.forum_info as Dict || {};
            this.forumAvatar = getStr(forumInfo, 'avatar', 'head', 'forum_avatar', 'icon');
          }
          if (!this.forumAvatar && this.forumName) {
            this.forumAvatar = 'http://tb.himg.baidu.com/sys/portraitn/item/' + this.forumName + '?time=' + Date.now();
          }
        }
      const rawUserList = data.user_list || (data.data as Dict)?.user_list || [];
console.info('TiebaLite: [D5] building userMap');
      this._userMap = this.buildUserMap(Array.isArray(rawUserList) ? rawUserList as Dict[] : []);
      this.collectManagerInfo(data);
      console.info('TiebaLite: [D6] extractThreadInfo');
      this.threadData = this.extractThreadInfo(data);
      void this.loadLocalLikeState();
      const rawPosts = data.post_list || (data.data as Dict)?.post_list || [];
      const firstPost = Array.isArray(rawPosts) && rawPosts.length > 0 ? rawPosts[0] as Dict : null;
      this._firstPostId = Number(firstPost?.id || 0);
      HistoryRepository.getInstance().saveThreadHistory({
        id: this.threadId,
        tid: this.threadId,
        title: this.threadData?.title || '',
        authorName: this.threadData?.authorName || '',
        authorPortrait: this.threadData?.authorPortrait || '',
        forumName: this.forumName,
        forum: this.forumName,
        pid: Number(firstPost?.id || 0),
        content: this.threadData?.content || [],
        firstPostContent: firstPost?.content || this.threadData?.content || [],
        media: this.threadData?.media || (data.thread as Dict)?.media || [],
        agree: (firstPost?.agree as Dict) || null,
        replyNum: Number(this.threadData?.replyNum || this.threadData?.reply_num || 0)
      }).catch(() => {});
      console.info('TiebaLite: [D7] extractPosts');
      const pageInfo = (data.page as Dict) || (data.data as Dict)?.page as Dict || {};
      this.totalPage = Number(pageInfo.totalPage || pageInfo.total_page || 0);
      if (this.sortType === 1 && reqPage === 1) {
        console.info('TiebaLite: [D7a] reverse sort, totalPage=' + this.totalPage);
        if (this.totalPage > 1) {
          const lastData: Dict = await this.repo.loadThreadPage(this.threadId, this.totalPage, this.seeLz, this.sortType);
          console.info('TiebaLite: [D7b] last page loaded totalPage=' + this.totalPage);
          if (lastData) {
            this.collectManagerInfo(lastData);
            const lastUserList = lastData.user_list || (lastData.data as Dict)?.user_list || [];
            if (Array.isArray(lastUserList)) {
              for (const u of lastUserList as Dict[]) {
                if (u) { const uid = Number(u.id || u.user_id); if (uid > 0 && !this._userMap.has(uid)) this._userMap.set(uid, u); }
              }
            }
            this.posts = this.extractPosts(lastData, this.totalPage);
            this.page = this.totalPage;
            this.hasMore = this.page > 1;
            console.info('TiebaLite: [D7c] posts.length=' + this.posts.length + ' page=' + this.page);
          } else {
            this.posts = this.extractPosts(data, reqPage);
            this.page = reqPage;
            this.hasMore = !this.isLastPage(data);
          }
        } else {
          this.posts = this.extractPosts(data, reqPage);
          this.page = reqPage;
          this.hasMore = !this.isLastPage(data);
        }
      } else {
        this.posts = this.extractPosts(data, reqPage);
        this.page = reqPage;
        this.hasMore = !this.isLastPage(data);
      }
      void this.prefetchAllThreadImages();
      console.info('TiebaLite: [D9] loadThread done page=' + this.page);
    } catch (e) {
      console.error('TiebaLite: [DERR] loadThread error=' + String(e));
      if (!silent) {
        const errObj = e as Dict;
        this.error = String(errObj?.msg || errObj?.message || '加载失败');
      }
    } finally {
      if (!silent) { this.loading = false; }
      console.info('TiebaLite: [D10] loadThread finally');
    }
  }

  private isThreadAuthorBlocked(): boolean {
    const blockRepo = BlockRepository.getInstance();
    const authorId = Number(this.threadData?.authorId || this.threadData?.author_id || 0);
    if (authorId > 0 && blockRepo.isUserBlocked(authorId)) return true;
    return blockRepo.isContentBlocked('', this.getPlainText(this.threadData?.content as Dict[]));
  }

  private getPlainText(contents: Dict[]): string {
    if (!contents) return '';
    let text = '';
    for (const c of contents) {
      const t = Number(c.type);
      if (t === 0) {
        text += String(c.text || c.c || '');
      } else if (t === 2 || t === 6 || t === 7 || t === 9 || t === 10 || t === 11 || t === 12 || t === 13) {
        text += String(c.c || c.text || '');
      } else if (t === 1) {
        text += String(c.text || c.c || '');
      } else if (t === 3) {
        text += String(c.text || c.c || '');
      } else if (t === 4) {
        text += String(c.text || c.c || '');
      }
    }
    return text;
  }

  private adjustKbExtra(delta: number): void {
    const v = this.kbExtra + delta;
    this.kbExtra = v;
    AppStorage.SetOrCreate('replyKbExtraV2', v);
    PreferencesManager.getInstance().putInt('replyKbExtraV2', v).catch(() => {});
    if (this._lastKbHpx > 0) {
      this.keyboardHeight = Math.max(0, this._lastKbHpx / this._density - this._winGapVp - this.kbExtra - 30);
    }
    promptAction.showToast({ message: '键盘补偿: ' + v + 'vp', duration: 800 });
  }

  private toggleEmojiPanel(): void {
    if (this.showEmojiPanel) {
      animateTo({ duration: 200 }, () => { this.showEmojiPanel = false; });
    } else {
      try { inputMethod.getController().stopInputSession(); } catch (_e) {}
      animateTo({ duration: 200 }, () => { this.showEmojiPanel = true; });
    }
    this.scheduleReplyScroll(280);
  }

  private updateReplyEditorH(): void {
    const lines = Math.max(1, Math.ceil(this.replyContent.length / 18));
    this.replyEditorH = Math.min(112, Math.max(46, 22 + lines * 26));
  }

  private getMenuAdjustedX(): number {
    const menuWidth = 160;
    const gap = 5;
    if (this.menuX < this.screenWidth / 2) {
      return Math.max(gap, this.menuX + gap);
    } else {
      return Math.min(this.screenWidth - menuWidth - gap, this.menuX - menuWidth - gap);
    }
  }

  private getMenuAdjustedY(): number {
    const menuHeight = 170;
    const minGap = 4;
    if (this.menuY < this.screenHeight / 2) {
      return Math.max(minGap, this.menuY);
    } else {
      return Math.min(this.screenHeight - menuHeight - minGap, this.menuY - menuHeight);
    }
  }

  private copyToClipboard(text: string): void {
    if (!text) return;
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      const pb = pasteboard.getSystemPasteboard();
      void pb.setData(data);
      promptAction.showToast({ message: '已复制', duration: 1000 });
    } catch (e) {
      console.error('TiebaLite: copyToClipboard error=' + String(e));
    }
  }

  private reportPost(postId: number): void {
    const url = 'https://tieba.baidu.com/p/' + this.threadId + '?pid=' + (postId > 0 ? postId : this._firstPostId);
    NavigationHelper.navigate('pages/webview/WebViewPage', { url: url, title: '举报' });
  }

  private async deletePost(postId: number): Promise<void> {
    try {
      await this.repo.deletePost(this.forumId, this.forumName, this.threadId, postId > 0 ? postId : this._firstPostId);
      promptAction.showToast({ message: '已删除', duration: 1000 });
      if (postId === 0 || postId === this._firstPostId) {
        NavigationHelper.back();
      } else {
        this.repo.clearThreadCache();
        const page1Data = await this.repo.loadThreadPage(this.threadId, 1, this.seeLz, this.sortType);
        const pInfo = (page1Data.page as Dict) || (page1Data.data as Dict)?.page as Dict || {};
        const total = Number(pInfo.totalPage || pInfo.total_page || 0);
        const targetPage = this.sortType === 0 && total > 1 ? total : 1;
        await this.loadThread(targetPage);
      }
    } catch (e) {
      promptAction.showToast({ message: '删除失败', duration: 2000 });
    }
  }

  private async bookmarkPost(postId: number): Promise<void> {
    if (!AccountManager.getInstance().isLoggedIn()) {
      NavigationHelper.navigate('pages/login/LoginPage');
      return;
    }
    try {
      await ThreadStoreRepository.getInstance().addStore(this.threadId, postId);
      promptAction.showToast({ message: '已收藏', duration: 1000 });
    } catch (e) {
      promptAction.showToast({ message: '收藏失败', duration: 1500 });
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%').height('100%')
        .backgroundColor(pageBg(this.isDark))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      Column() {
      Column() {
      Row() {
        Image($r('app.media.ic_arrow_back')).width(Math.round(22 * this.fontScale)).height(Math.round(22 * this.fontScale)).fillColor(textPrimary(this.isDark)).onClick(() => NavigationHelper.back())
        Blank()
        if (this.forumName) {
          Row() {
            Avatar({ portrait: buildPortraitUrl(this.forumAvatar), avatarSize: 30, defaultName: this.forumName })
              .width(30).height(30)
            Text(this.forumName)
              .fontFamily(this.appFontFamily).fontSize(Math.round(18 * this.fontScale)).fontColor(textPrimary(this.isDark)).fontWeight(FontWeight.Bold)
              .margin({ left: 6 })
          }
          .padding({ left: 14, right: 18, top: 5, bottom: 5 })
          .backgroundColor(blendWithBg(this.primaryColor, 0.24, this.isDark, '#1E1E1E')).borderRadius(22)
          .onClick(() => {
            NavigationHelper.navigate('pages/forum/ForumPage', {
              forumName: this.forumName, forumId: String(this.forumId)
            });
          })
        }
        Blank()
        Blank().width(22).height(22)
      }
      .padding({ left: 12, right: 12, top: this.showForumBar ? 8 : 0, bottom: this.showForumBar ? 8 : 0 })
      .height(this.showForumBar ? 56 : 0)
      .clip(true)
      .animation({ duration: 200, curve: Curve.FastOutSlowIn })
      .width('100%')

      if (this.showFixedBar) {
        this.actionBarRow(true)
      }
      }
      .width('100%')
      .backgroundColor(withAlpha(pageBg(this.isDark), 1 - this.headerAlpha / 100))
      .backdropBlur(60)
      .border({ width: { bottom: this.showFixedBar ? 0 : 1 }, color: blendWithBg(this.primaryColor, 0.15, this.isDark, '#1E1E1E') })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
      .position({ x: 0, y: 0 })
      .zIndex(2)
      .onAreaChange((_old: Area, newArea: Area) => {
        const h = newArea.height as number;
        if (h > 0) {
          const hh = h - this.topInset - (this.showFixedBar ? 44 : 0);
          if (hh > 40 && Math.abs(hh - this.headerH) > 1) {
            this.headerH = hh;
          }
        }
      })
      if (this.loading) {
          LoadingState({ message: '加载中...' })
        } else if (this.error.length > 0) {
          ErrorState({ message: this.error, onRetryAction: (): void => { void this.loadThread(); } })
        } else {
          Stack() {
            PullToRefresh({
              scroller: this.scroller,
              reduceEffects: this.reduceEffects,
              isRefreshing: this.isRefreshing,
              onRefresh: (): void => { this.isRefreshing = true; },
              onTimeout: (): void => { this.isRefreshing = false; }
            }) {
            Scroll(this.scroller) {
              Column() {
                Blank().height(this.showForumBar ? this.headerH : Math.max(0, this.headerH - 56)).animation({ duration: 200, curve: Curve.FastOutSlowIn })
                Column() {
                if (this.threadData) {
                  Row() {
                    Avatar({ portrait: buildPortraitUrl(String(this.threadData!.authorPortrait || '')), avatarSize: 40, defaultName: String(this.threadData!.authorName || '') })
                      .onClick(() => {
                        if (Number(this.threadData!.authorId || 0) > 0) {
                          NavigationHelper.navigate('pages/user/UserProfilePage', { uid: String(this.threadData!.authorId) });
                        }
                      })
                    Column() {
                      Row() {
                  Text(String(this.threadData!.authorName || ''))
                          .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(darkenColor(this.primaryColor, this.isDark ? 0.25 : 0.55)).fontWeight(FontWeight.Bold)
                          .onClick(() => {
                            if (Number(this.threadData!.authorId || 0) > 0) {
                              NavigationHelper.navigate('pages/user/UserProfilePage', { uid: String(this.threadData!.authorId) });
                            }
                          })
                        if (Number(this.threadData!.authorId || 0) > 0) {
                  Text('楼主')
                            .fontFamily(this.appFontFamily).fontSize(10).fontColor('#FF6B35').fontWeight(FontWeight.Bold)
                            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                            .backgroundColor(blendWithBg('#FF6B35', 0.15, this.isDark))
                            .borderRadius(10)
                            .margin({ left: 6 })
                        }
                        if (this.getAuthorBawuRole(this.threadData!.author as Dict, Number(this.threadData!.authorId || 0)) === 1) {
                          Text('吧主')
                            .fontFamily(this.appFontFamily).fontSize(10).fontColor('#FFB800').fontWeight(FontWeight.Bold)
                            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                            .backgroundColor(blendWithBg('#FFB800', 0.15, this.isDark))
                            .borderRadius(10)
                            .margin({ left: 6 })
                        } else if (this.getAuthorBawuRole(this.threadData!.author as Dict, Number(this.threadData!.authorId || 0)) === 2) {
                          Text('小吧主')
                            .fontFamily(this.appFontFamily).fontSize(10).fontColor('#4477E0').fontWeight(FontWeight.Bold)
                            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                            .backgroundColor(blendWithBg('#4477E0', 0.15, this.isDark))
                            .borderRadius(10)
                            .margin({ left: 6 })
                        }
                        if (Number(this.threadData.authorLevel) > 0) {
                          Text('Lv.' + String(Number(this.threadData.authorLevel)))
                            .fontFamily(this.appFontFamily).fontSize(Math.round(11 * this.fontScale)).fontColor(this.getLevelColor(Number(this.threadData.authorLevel))).fontWeight(FontWeight.Bold)
                            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                            .backgroundColor(blendWithBg(this.getLevelColor(Number(this.threadData.authorLevel)), 0.15, this.isDark))
                            .borderRadius(10).margin({ left: 6 })
                        }
                      }
                      .width('100%')
                      Row() {
                        Text(this.formatUnixTime(Number(this.threadData.createTime || 0)))
                          .fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textTertiary(this.isDark)).letterSpacing(1)
                        if (this.threadData.authorIp) {
                          Text(' · ' + String(this.threadData.authorIp))
                            .fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor('#AAAAAA').letterSpacing(1)
                        }
                      }
                      .width('100%')
                    }
                    .margin({ left: 10 })
                    .layoutWeight(1)
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 12 })
                  .margin({ bottom: 8 })

                  Text(String(this.threadData!.title || ''))
                    .fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontWeight(FontWeight.Bold)
                    .fontColor(textPrimary(this.isDark))
                    .width('100%')
                    .padding({ left: 16, right: 16, bottom: 10 })

                  Column() {
                    if (this.threadData.content) {
                      if (this.isThreadAuthorBlocked()) {
                        Column() {
                          Text('楼主内容已被屏蔽').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark))
                            .width('100%').padding(16).textAlign(TextAlign.Center)
                        }
                        .width('100%')
                        .padding({ left: 12, right: 6, bottom: 12 })
                      } else {
                        Column() {
                        PbContentRender({ contents: this.threadData.content as Dict[], allImageUrls: this.allThreadImageUrls, allImageStartIndex: 0, threadId: this.threadId, forumId: this.forumId, forumName: this.forumName })
                        .onAppear(() => {
                          const c = this.threadData!.content as Dict[];
                          if (Array.isArray(c) && c.length > 0) {
                            for (let i = 0; i < c.length && i < 3; i++) {
                              console.info('TiebaLite: fp[' + i + '] type=' + c[i].type + ' text="' + String(c[i].text || '').substring(0, 50) + '" c="' + String(c[i].c || '').substring(0, 30) + '"');
                            }
                          }
                        })
                  .padding({ left: 12, right: 6, bottom: 12 })
                        }
                        .gesture(
                          LongPressGesture({ repeat: false, duration: 500 })
                            .onAction((event: GestureEvent) => {
                              this.menuText = this.getPlainText(this.threadData!.content as Dict[]);
                              this.menuPostId = 0;
                              this.menuPostAuthorId = Number(this.threadData?.authorId || 0);
                              this.menuX = event.fingerList[0].globalX;
                              this.menuY = event.fingerList[0].globalY;
                              this.menuShow = true;
                            })
                        )
                      }
                    }
                  }
                  .width('100%')
                  .padding(0)
                  Divider().height(1).color(dividerColor(this.isDark)).width('100%')
                }

                if (this.threadData?.pollInfo) {
                  this.pollWidget(this.threadData.pollInfo as Dict)
                }
              }
              .width('100%')
              .onAreaChange((_old, newVal) => {
                this.contentAboveHeight = newVal.height as number;
              })

              Column() {
                this.actionBarRow(false)
              }
              .visibility(this.showFixedBar ? Visibility.Hidden : Visibility.Visible)

              Column() {
                ForEach(Array.isArray(this.posts) ? this.posts : [], (post: Dict, index: number) => {
                  Column() {
                    this.postItem(post)
                  }
.margin({ bottom: 12 })
                  .transition(TransitionEffect.opacity(0).combine(TransitionEffect.translate({ x: 0, y: 20 })))
                  .onAreaChange((_o: Area, a: Area) => {
                    const key = Number(post.id || post.pid || 0);
                    if (key > 0) {
                      const gy = a.globalPosition.y as number;
                      const h = a.height as number;
                      const info = new PostPosInfo();
                      info.y = gy + this.scroller.currentOffset().yOffset;
                      info.h = h;
                      this._postPosMap.set(key, info);
                      if (this.showReply && key === this.replyPostId) {
                        this.scheduleReplyScroll(350);
                      }
                    }
                  })
                })

                if (this.hasMore) {
                  Row() {
                    if (this.loadingMore && AppStorage.get<number>('refreshStyle') === 1) {
                      GearLoading({ gearSize: 24, color: darkenColor(this.primaryColor, 0.2), text: '加载中...' })
                    } else if (this.loadingMore) {
                    } else {
                      Text('加载更多...')
                        .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark))
                        .onClick(() => { void this.loadMore(); })
                    }
                  }
                  .width('100%').justifyContent(FlexAlign.Center).padding(16)
                } else if (this.posts.length > 0) {
                  Text('—— 到底了 ——')
                    .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark))
                    .width('100%').textAlign(TextAlign.Center).padding({ left: 24, right: 24, top: 16, bottom: 6 })
                }
              }
              .width('100%')
              .padding({ left: 8, right: 8, bottom: 4 })
            }
            .width('100%').constraintSize({ minHeight: '100%' }).justifyContent(FlexAlign.Start).padding({ bottom: 10 })
          }
            .scrollBar(BarState.Off)
        .width('100%')
        .layoutWeight(1)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .backgroundColor(pageBg(this.isDark))
          .edgeEffect(this.reduceEffects ? EdgeEffect.None : EdgeEffect.Spring)
          .onReachEnd(() => {
            if (this.hasMore && !this.loadingMore) {
              void this.loadMore();
            }
          })
          .onScroll(() => {
            const newY = this.scroller.currentOffset().yOffset;
            const delta = newY - this.lastScrollY;
            if (delta > 5 && this.showBottomBar) {
              animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => { this.showBottomBar = false; });
            } else if (delta < -5 && !this.showBottomBar) {
              animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => { this.showBottomBar = true; });
            }
            if (delta > 5 && this.showScrollTop && newY > 500) {
              animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => { this.showScrollTop = false; });
            } else if (delta < -5 && !this.showScrollTop && newY > 500) {
              animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => { this.showScrollTop = true; });
            }
            if (this.hideOnScroll && !this.showReply) {
              if (delta > 5 && this.showForumBar && newY > 40) {
                this.showForumBar = false;
              } else if (delta < -5 && !this.showForumBar) {
                this.showForumBar = true;
              }
            }
            this.lastScrollY = newY;
            this.scrollTop = newY;
            this.showFixedBar = this.scrollTop >= this.contentAboveHeight;
          })
            }
        }
        .alignContent(Alignment.TopStart)
        .width('100%')
        .layoutWeight(1)
        .backgroundColor(this.isDark ? 'rgba(30,30,30,0.75)' : 'rgba(255,255,255,0.65)')
        .backdropBlur(40)
      }

      if (this.scrollTop > 500) {
        Image($r('app.media.ic_arrow_up')).width(Math.round(22 * this.fontScale)).height(Math.round(22 * this.fontScale))
          .fillColor(onPrimaryContainer(this.isDark))
          .width(44).height(44).borderRadius(22 * this.fabRadius / 100)
          .backgroundColor(primaryContainer(this.isDark))
          .shadow({ radius: 6, color: shadowColor(this.isDark), offsetY: 3 })
          .position({ bottom: 64, right: 16 })
          .translate({ x: this.showScrollTop ? (this.fabLeft ? -(this.screenWidth - 76) : 0) : (this.fabLeft ? -(this.screenWidth - 76) - 60 : 60) })
          .onClick(() => {
            this.scroller.scrollEdge(Edge.Top);
          })
      }

      if (this.showBottomBar) {
        Row() {
          Stack() {
            Canvas(this.liquidCtx)
              .width('100%')
              .height('100%')
              .hitTestBehavior(HitTestMode.None)
            Row() {
              Row() {
                Image($r('app.media.ic_forum')).width(Math.round(18 * this.fontScale)).height(Math.round(18 * this.fontScale)).fillColor(textSecondary(this.isDark))
                Text(' 说点什么...').fontFamily(this.appFontFamily).fontSize(16 * this.fontScale).fontColor(textSecondary(this.isDark))
              }
              .padding({ left: 16 }).layoutWeight(1)
                .onClick(() => {
                    if (!AccountManager.getInstance().isLoggedIn()) { NavigationHelper.navigate('pages/login/LoginPage'); return; }
                    this.replyPostId = 0;
                    this.replyUserId = 0;
                    this.replyHint = '';
                    this.showReply = true;
                    this.openReply();
                  }, 12)
                if (!this.showMenu) {
                  Column() {
                    if (this.isCollected) {
                      Image($r('app.media.ic_star')).width(Math.round(22 * this.fontScale)).height(Math.round(22 * this.fontScale)).fillColor('#FFAA00')
                    } else {
                      Image($r('app.media.ic_star_outline')).width(Math.round(22 * this.fontScale)).height(Math.round(22 * this.fontScale)).fillColor(textSecondary(this.isDark))
                    }
                  }
                  .margin({ right: 14 }).alignItems(HorizontalAlign.Center).height(44).justifyContent(FlexAlign.Center)
                  .onClick(() => { void this.toggleCollect(); })
                  Image($r('app.media.ic_target')).width(Math.round(22 * this.fontScale)).height(Math.round(22 * this.fontScale)).fillColor(textSecondary(this.isDark)).margin({ right: 16 })
                    .onClick(() => this.showJumpDialog())
                  Stack({ alignContent: Alignment.Center }) {
                    if (this.liked) {
                      Image($r('app.media.ic_favorite')).width(Math.round(22 * this.fontScale)).height(Math.round(22 * this.fontScale)).fillColor('#FF4444')
                    } else {
                      Image($r('app.media.ic_favorite')).width(Math.round(22 * this.fontScale)).height(Math.round(22 * this.fontScale)).fillColor(textSecondary(this.isDark)).opacity(0.5)
                    }
                    if (this.likeCount > 0) {
                      Text(this.formatCount(this.likeCount))
                        .fontFamily(this.appFontFamily).fontSize(Math.round(9 * this.fontScale)).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
                        .padding({ left: 3, right: 3, top: 1, bottom: 1 })
                        .backgroundColor(this.liked ? '#FF4444' : textSecondary(this.isDark))
                        .borderRadius(6)
                        .position({ top: 6, right: -8 })
                    }
                  }
                  .margin({ right: 16 }).height(44)
                  .onClick(() => { void this.toggleLike(); })
                  Image($r('app.media.ic_more_vert')).width(Math.round(26 * this.fontScale)).height(Math.round(26 * this.fontScale)).fillColor(textSecondary(this.isDark)).margin({ right: 14 })
                    .onClick(() => {
                      if (!AccountManager.getInstance().isLoggedIn()) { NavigationHelper.navigate('pages/login/LoginPage'); return; }
                      const account = AccountManager.getInstance().getCurrentAccountSync();
                      this.isThreadAuthor = !!(account && this.threadData && Number(this.threadData.authorId) === account.uid);
                      this.showMenu = true;
                    })
                }
            }
            .height(50)
            .width('100%')
          }
          .height(50)
          .width('100%')
          .onTouch((event: TouchEvent) => this.handleBarTouch(event))
          .backgroundColor(withAlpha(blendWithBg(this.secondaryColor, 0.18, this.isDark, '#1E1E1E'), 0.75))
          .backdropBlur(60)
          .borderRadius(24)
          .clip(true)
          .border({ width: 1, color: blendWithBg(this.secondaryColor, 0.35, this.isDark, '#1E1E1E') })
          .shadow({ radius: 12, color: this.isDark ? '#40000000' : '#20000000', offsetY: 6 })
          .onAreaChange((_old: Area, newArea: Area) => {
            const w = newArea.width as number;
            if (w > 0 && Math.abs(w - this.barWidth) > 0.5) {
              this.barWidth = w;
            }
          })
        }
        .width('100%')
        .padding({ left: 32, right: 32, bottom: 12 })
        .width('100%')
        .position({ bottom: 0 })
        .transition(TransitionEffect.translate({ y: 80 }).combine(TransitionEffect.opacity(0)))
      }

      if (this.loadingMore) {
        Column() {
          GearCycle({ gearSize: 40, color: darkenColor(this.primaryColor, 0.2), refreshing: true })
        }
        .width('100%')
        .position({ bottom: 100, left: 0, right: 0 })
        .zIndex(10)
      }

      if (this.showMenu) {
        Column() {
          Column()
            .width('100%').layoutWeight(1)
            .onClick(() => { this.showMenu = false; })
          Column() {
            Row() {
              Text('分享').fontFamily(this.appFontFamily).fontSize(15).fontColor(textPrimary(this.isDark))
            }
            .height(44).padding({ left: 16, right: 16 })
            .onClick(() => { this.shareThread(); this.showMenu = false; })
            Divider().height(0.5).color(dividerColor(this.isDark))
            Row() {
              Text('复制链接').fontFamily(this.appFontFamily).fontSize(15).fontColor(textPrimary(this.isDark))
            }
            .height(44).padding({ left: 16, right: 16 })
            .onClick(() => { this.copyLink(); this.showMenu = false; })
            Divider().height(0.5).color(dividerColor(this.isDark))
            Row() {
              Text('举报').fontFamily(this.appFontFamily).fontSize(15).fontColor(textPrimary(this.isDark))
            }
            .height(44).padding({ left: 16, right: 16 })
            .onClick(() => { this.reportThread(); this.showMenu = false; })
            if (this.isThreadAuthor) {
              Divider().height(0.5).color(dividerColor(this.isDark))
              Row() {
                Text('删除').fontFamily(this.appFontFamily).fontSize(15).fontColor('#FF4444')
              }
              .height(44).padding({ left: 16, right: 16 })
              .onClick(() => {
                this.showMenu = false;
                promptAction.showToast({ message: '正在删除...', duration: 1500 });
                void this.deleteOwnThread();
              })
            }
          }
          .backgroundColor(cardBg(this.isDark)).borderRadius(12)
          .shadow({ radius: 16, color: shadowColor(this.isDark), offsetY: 8 })
          .margin({ right: 46, bottom: 12 })
          .width(160)
        }
        .width('100%').height('100%')
        .position({ x: 0, y: 0 })
        .alignItems(HorizontalAlign.End)
        .padding({ bottom: 76 })
        .backgroundColor('#33000000')
      }

      if (this.showJump) {
        Column() {
          Column()
            .width('100%').layoutWeight(1)
            .onClick(() => { this.showJump = false; })
          Column() {
            TextInput({ text: this.jumpPageText, placeholder: this.page + '/' + this.totalPage + ' 输入页码' })
              .width('100%').height(40).backgroundColor(pageBg(this.isDark)).borderRadius(20).padding({ left: 16 })
              .onChange((v: string) => { this.jumpPageText = v; })
              .type(InputType.Number)
            Button('跳转').width('100%').height(36)
              .backgroundColor(this.primaryColor).fontColor('#FFFFFF').borderRadius(18).margin({ top: 8 })
              .onClick(() => { this.doJumpPage(); })
          }.padding({ left: 16, right: 16, top: 12, bottom: 16 }).width('100%').backgroundColor(cardBg(this.isDark))
        }
        .width('100%').height('100%')
        .position({ bottom: this.keyboardHeight })
      }

      if (this.showReply && this.showRiskWarning) {
        Column() {
          Column()
            .width('100%').layoutWeight(1)
            .onClick(() => { this.showReply = false; this.showRiskWarning = false; })
          Column() {
            Row() {
              Text('回复').fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontWeight(FontWeight.Bold)
              Blank()
              Button('取消').fontColor(textSecondary(this.isDark)).backgroundColor('transparent').onClick(() => { this.showReply = false; this.showRiskWarning = false; })
            }.padding({ left: 12, right: 12, top: 8, bottom: 4 }).width('100%')
            Column() {
              Row() {
                Image($r('app.media.ic_warning')).width(Math.round(18 * this.fontScale)).height(Math.round(18 * this.fontScale)).fillColor('#FF4444')
                Text('风险提示').fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontWeight(FontWeight.Bold).fontColor('#FF4444').margin({ left: 4 })
              }
              Text('第三方客户端可能导致账号被封禁，请谨慎使用！')
    .fontFamily(this.appFontFamily).fontSize(Math.round(13 * this.fontScale)).fontColor(textSecondary(this.isDark))
              Row() {
                Checkbox().select(this.riskNeverAgainChecked)
                  .onChange((v: boolean) => { this.riskNeverAgainChecked = v; })
                Text('不再提示').fontFamily(this.appFontFamily).fontSize(Math.round(13 * this.fontScale)).fontColor(textSecondary(this.isDark)).margin({ left: 6 })
              }
              .margin({ top: 8 })
              .onClick(() => { this.riskNeverAgainChecked = !this.riskNeverAgainChecked; })
            }
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .width('100%')
            .backgroundColor('#FFF0F0')
            .borderRadius(12)
            Button('同意并继续').width('100%').height(44)
              .backgroundColor(this.primaryColor).fontColor('#FFFFFF').borderRadius(22).margin({ top: 8 })
              .onClick(() => {
                if (this.riskNeverAgainChecked) {
                  PreferencesManager.getInstance().putBoolean('reply_risk_agreed', true);
                }
                this.agreeToRisk = true;
                this.showRiskWarning = false;
              })
          }.padding({ left: 16, right: 16, top: 8, bottom: 8 }).width('100%').backgroundColor(blendWithBg(this.primaryColor, 0.15, this.isDark))
        }
        .width('100%').height('100%')
        .position({ bottom: 0 })
      } else if (this.showReply) {
        Column() {
          Column()
            .width('100%').layoutWeight(1)
            .backgroundColor('#33000000')
            .onClick(() => { this.closeReplyWindow(); })
          Column() {
            Row() {
              Text(this.replyHint || '回复本帖').fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontWeight(FontWeight.Medium).fontColor(textPrimary(this.isDark))
              Blank()
            }
            .width('100%').padding({ left: 0, right: 0, top: 12, bottom: 8 })
            RichEditor({ controller: this.richController })
              .placeholder('空空如也', { font: { size: 16 }, fontColor: textTertiary(this.isDark) })
              .width('100%').height(this.replyEditorH)
              .backgroundColor(cardBg(this.isDark)).borderRadius(12)
              .border({ width: 1, color: this.primaryColor })
              .padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .onReady(() => { this.richController.setTypingStyle({ fontSize: 16, fontColor: textPrimary(this.isDark) }); })
              .onIMEInputComplete(() => { this.replyContent = richEditorToText(this.richController); this.updateReplyEditorH(); })
              .onDeleteComplete(() => { this.replyContent = richEditorToText(this.richController); this.updateReplyEditorH(); })
              .onPaste(() => { this.replyContent = richEditorToText(this.richController); this.updateReplyEditorH(); })

            if (this.selectedImageUris.length > 0) {
              Scroll() {
                Row() {
                  ForEach(this.selectedImageUris, (uri: string, idx: number) => {
                    Stack() {
                      Image(uri)
                        .width(64).height(64).borderRadius(8).objectFit(ImageFit.Cover)
                      Image($r('app.media.ic_close')).width(14).height(14).fillColor('#FFFFFF')
                        .width(20).height(20)
                        .backgroundColor('rgba(0,0,0,0.5)').borderRadius(10)
                        .align(Alignment.TopEnd)
                        .onClick(() => {
                          this.selectedImageUris = this.selectedImageUris.filter((_, i) => i !== idx);
                          this.imageUploadResults = this.imageUploadResults.filter((_, i) => i !== idx);
                        })
                    }.width(64).height(64).margin({ right: 8 })
                  })
                }.padding({ left: 4, right: 4 })
              }
                .scrollBar(BarState.Off).height(76).width('100%')
            }

            Row() {
              Button() {
                Image($r('app.media.ic_emoji')).width(24).height(24)
              }
              .type(ButtonType.Normal)
              .width(40).height(32)
              .padding(0)
              .backgroundColor(Color.Transparent)
              .onClick(() => {
                if (Date.now() - this._kbAdjustAt < 600) return;
                this.toggleEmojiPanel();
              })
              .gesture(
                LongPressGesture({ repeat: false, duration: 500 })
                  .onAction(() => { this._kbAdjustAt = Date.now(); this.adjustKbExtra(10); })
              )
              Image($r('app.media.ic_image_add')).width(24).height(24).margin({ left: 16 }).onClick(() => { this.pickImages(); })
              if (this.selectedImageUris.length > 0) {
                Text(String(this.selectedImageUris.length)).fontFamily(this.appFontFamily).fontSize(12).fontColor(textAccent(this.primaryColor, this.isDark))
                  .width(18).height(18).textAlign(TextAlign.Center).backgroundColor(blendWithBg(this.primaryColor, 0.12, this.isDark)).borderRadius(9)
                  .margin({ left: 2 })
              }
              Blank()
              Text(String(this.replyContent.length) + '/10000').fontFamily(this.appFontFamily).fontSize(12).fontColor(textSecondary(this.isDark)).margin({ right: 8 })
Text(this.uploadingImages ? '上传中...' : '发送')
                .width(64).height(26).textAlign(TextAlign.Center)
                .backgroundColor((this.replyContent.length > 0 || this.selectedImageUris.length > 0) && !this.uploadingImages ? blendWithWhite(this.primaryColor, 0.35) : blendWithWhite(this.primaryColor, 0.25))
                .fontColor((this.replyContent.length > 0 || this.selectedImageUris.length > 0) && !this.uploadingImages ? '#0B2E6C' : '#8B96B4')
                .fontSize(15).fontWeight(FontWeight.Bold).borderRadius(12)
                .onClick(() => {
                  if (Date.now() - this._kbAdjustAt < 600) return;
                  if (!this.uploadingImages && (this.replyContent.length > 0 || this.selectedImageUris.length > 0)) {
                    this.sendReply();
                  }
                })
                .gesture(
                  LongPressGesture({ repeat: false, duration: 500 })
                    .onAction(() => { this._kbAdjustAt = Date.now(); this.adjustKbExtra(-10); })
                )
            }.width('100%').padding({ top: 4, bottom: 8 })

            if (this.showEmojiPanel) {
              Stack() {
                Column()
                  .width('100%').height(220)
                  .onClick(() => { this.showEmojiPanel = false; })
                this.EmojiPanel()
              }
              .width('100%')
            }
          }.padding({ left: 16, right: 16, top: 4, bottom: 0 }).width('100%').backgroundColor(blendWithBg(this.primaryColor, 0.18, this.isDark, '#1E1E1E'))
            .onAreaChange((_o: Area, a: Area) => {
              const h = a.height as number;
              if (h > 40) {
                this.replyPanelH = h;
                this.scheduleReplyScroll(350);
              }
            })
        }
        .width('100%').height('100%')
        .position({ bottom: this.keyboardHeight > 0 ? this.keyboardHeight : -this._winGapVp })
      }

      if (this.menuShow) {
        Column() {
          Column() {
            Row() {
              Image($r('app.media.ic_edit')).width(20).height(20).fillColor(this.primaryColor)
              Text('复制').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark)).margin({ left: 12 })
              Blank()
            }
            .width('100%').height(52).padding({ left: 20, right: 20 })
            .onClick(() => { this.copyToClipboard(this.menuText); this.menuShow = false; })
            Divider().height(0.5).color(dividerColor(this.isDark)).margin({ left: 52 })
            if (AccountManager.getInstance().getCurrentAccountSync()?.uid === this.menuPostAuthorId && this.menuPostAuthorId > 0) {
              Row() {
                Image($r('app.media.ic_favorite')).width(20).height(20).fillColor('#FF4444')
                Text('删除').fontFamily(this.appFontFamily).fontSize(16).fontColor('#FF4444').margin({ left: 12 })
                Blank()
              }
              .width('100%').height(52).padding({ left: 20, right: 20 })
              .onClick(() => { void this.deletePost(this.menuPostId); this.menuShow = false; })
              Divider().height(0.5).color(dividerColor(this.isDark)).margin({ left: 52 })
            }
            Row() {
              Image($r('app.media.ic_block')).width(20).height(20).fillColor(this.primaryColor)
              Text('举报').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark)).margin({ left: 12 })
              Blank()
            }
            .width('100%').height(52).padding({ left: 20, right: 20 })
            .onClick(() => { this.reportPost(this.menuPostId); this.menuShow = false; })
            Divider().height(0.5).color(dividerColor(this.isDark)).margin({ left: 52 })
            Row() {
              Image($r('app.media.ic_star')).width(20).height(20).fillColor(this.primaryColor)
              Text('收藏到此楼').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark)).margin({ left: 12 })
              Blank()
            }
            .width('100%').height(52).padding({ left: 20, right: 20 })
            .onClick(() => { void this.bookmarkPost(this.menuPostId); this.menuShow = false; })
          }
          .width(160)
          .backgroundColor(cardBg(this.isDark)).borderRadius(12)
          .shadow({ radius: 16, color: shadowColor(this.isDark), offsetY: 8 })
          .position({ x: this.getMenuAdjustedX(), y: this.getMenuAdjustedY() })
        }
        .width('100%').height('100%')
        .position({ x: 0, y: 0 })
        .alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Start)
        .backgroundColor('#33000000')
        .onClick(() => { this.menuShow = false; })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    }
    .width('100%').height('100%')
    .backgroundColor(pageBg(this.isDark))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onTouch((event: TouchEvent) => {
      if (!GripDetector.isEnabled() || GripDetector.isNativeAvailable()) return;
      const side = GripDetector.touchSide(event.touches);
      if (side === -1 && !this.fabLeft) {
        this.switchFabSide(true);
      } else if (side === 1 && this.fabLeft) {
        this.switchFabSide(false);
      }
    })
    
  }

  private countImagesInContent(content: Dict[]): number {
    if (!Array.isArray(content)) return 0;
    let count = 0;
    for (const item of content) {
      const t = Number(item.type);
      if (t === 1 || t === 3 || t === 20) {
        const src = String(item.originSrc || item.src || item.origin_src || item.cdn_src || item.c || '');
        if (src) count++;
      }
    }
    return count;
  }

  private pidStartIndex(pidOrder: number[], pidCounts: Map<number, number>, pid: number): number {
    let sum = 0;
    for (const p of pidOrder) {
      if (p === pid) return sum;
      sum += pidCounts.get(p) || 0;
    }
    return -1;
  }

  private async prefetchAllThreadImages(): Promise<void> {
    if (this._photosPrefetched || !this.threadId) return;
    this._photosPrefetched = true;
    try {
      const res: ThreadImageCollectResult = await ThreadImageFetcher.fetch(this.threadId, this.totalPage);
      if (res.all.length === 0) {
        this._photosPrefetched = false;
        return;
      }
      this._allImagePidOrder = res.pidOrder;
      this._allImagePidCounts = res.pidCounts;
      this.allThreadImageUrls = res.all;
      PhotoUrlCache.map.set(String(this.threadId), res.all);
      console.info('TiebaLite: [PHOTO] prefetch all thread images count=' + res.all.length);
    } catch (e) {
      console.warn('TiebaLite: [PHOTO] prefetch failed ' + String(e));
      this._photosPrefetched = false;
    }
  }

  private getImageStartForReplyPost(post: Dict): number {
    if (this._allImagePidOrder.length > 0) {
      const pid = Number(post.id || post.pid || 0);
      if (pid > 0) {
        const start = this.pidStartIndex(this._allImagePidOrder, this._allImagePidCounts, pid);
        if (start >= 0) return start;
      }
    }
    const idx = this.posts.indexOf(post);
    if (idx < 0) return 0;
    let count = 0;
    if (this.threadData?.content) {
      count += this.countImagesInContent(this.threadData.content as Dict[]);
    }
    for (let i = 0; i < idx; i++) {
      if (this.posts[i].content) {
        count += this.countImagesInContent(this.posts[i].content as Dict[]);
      }
    }
    return count;
  }

  private collectManagerInfo(data: Dict): void {
    if (!data || typeof data !== 'object') return;
    const root = (data.data as Dict) || data;
    const lists: Dict[][] = [];
    const forum = root.forum as Dict;
    if (forum && Array.isArray(forum.managers)) lists.push(forum.managers as Dict[]);
    if (Array.isArray(root.managers)) lists.push(root.managers as Dict[]);
    if (Array.isArray(data.managers)) lists.push(data.managers as Dict[]);
    for (const list of lists) {
      for (const m of list) {
        if (!m || typeof m !== 'object') continue;
        const id = Number(m.id || m.user_id || m.uid || m.userId || 0);
        if (id <= 0) continue;
        this._managerIds.add(id);
        const role = Number(m.role || m.manager_level || m.managerLevel || 0);
        if (role === 1 || Number(m.is_bazhu || m.isBazhu || 0) === 1) {
          this._bazhuIds.add(id);
        }
      }
    }
    console.info('TiebaLite: [BAWU] managers=' + this._managerIds.size + ' bazhu=' + this._bazhuIds.size + ' userListSample=' + (() => {
      let s = '';
      let cnt = 0;
      for (const u of this._userMap.values()) {
        s += String(u.id) + ':' + JSON.stringify({ is_bawu: u.is_bawu, bawu_type: u.bawu_type, is_bazhu: u.is_bazhu }).substring(0, 120) + ' | ';
        cnt++;
        if (cnt >= 3) break;
      }
      return s;
    })());
  }

  private getAuthorBawuRole(author: Dict | undefined, authorId: number): number {
    if (author && typeof author === 'object') {
      const bazhu = Number(author.is_bazhu || author.isBazhu || 0);
      const bawu = Number(author.is_bawu || author.isBawu || 0);
      if (bazhu === 1) return 1;
      if (bawu === 1) return String(author.bawu_type || '') === 'manager' ? 1 : 2;
    }
    if (authorId > 0) {
      const user = this._userMap.get(authorId);
      if (user && typeof user === 'object') {
        const u = user as Dict;
        const bazhu = Number(u.is_bazhu || u.isBazhu || 0);
        const bawu = Number(u.is_bawu || u.isBawu || 0);
        if (bazhu === 1) return 1;
        if (bawu === 1) return String(u.bawu_type || '') === 'manager' ? 1 : 2;
      }
      if (this._bazhuIds.has(authorId)) return 1;
      if (this._managerIds.has(authorId)) return 2;
    }
    return 0;
  }

  private getPostBawuRole(post: Dict): number {
    return this.getAuthorBawuRole(post.author as Dict, Number(post.author_id || post.authorId || 0));
  }

  private resolvePostAuthorName(post: Dict): string {
    const author = post.author as Dict;
    if (author?.name_show || author?.name) return String(author.name_show || author.name || '');
    const authorId = Number(post.author_id || post.authorId || 0);
    if (authorId && this._userMap.has(authorId)) {
      const user = this._userMap.get(authorId) as Dict;
      return String(user.name_show || user.name || '');
    }
    return '';
  }

  private resolvePostAuthorPortrait(post: Dict): string {
    const author = post.author as Dict;
    if (author?.portrait) return String(author.portrait);
    const authorId = Number(post.author_id || post.authorId || 0);
    if (authorId && this._userMap.has(authorId)) {
      const user = this._userMap.get(authorId) as Dict;
      return String(user.portrait || '');
    }
    return '';
  }

  private resolvePostAuthorLevel(post: Dict): number {
    const author = post.author as Dict;
    if (author?.level_id) return Number(author.level_id);
    const authorId = Number(post.author_id || post.authorId || 0);
    if (authorId && this._userMap.has(authorId)) {
      const user = this._userMap.get(authorId) as Dict;
      return Number(user.level_id || 0);
    }
    return 0;
  }

  private resolvePostAuthorVipIcon(post: Dict): string {
    const author = post.author as Dict;
    if (!author) return '';
    return getStr(author, 'mb_icon', 'member_icon', 'vip_icon', 'v_icon');
  }

  private getLevelColor(level: number): string {
    if (level <= 0) return '#999999';
    if (level <= 3) return '#999999';
    if (level <= 6) return '#4CAF50';
    if (level <= 9) return '#4477E0';
    if (level <= 12) return '#9C27B0';
    if (level <= 15) return '#FF6B35';
    return '#E53935';
  }

  private resolvePostAuthorIp(post: Dict): string {
    const author = post.author as Dict;
    if (author?.ip_address) return String(author.ip_address);
    const authorId = Number(post.author_id || post.authorId || 0);
    if (authorId && this._userMap.has(authorId)) {
      const user = this._userMap.get(authorId) as Dict;
      return String(user.ip_address || '');
    }
    return '';
  }

  private formatPostTime(post: Dict): string {
    const ts = Number(post.time || post.create_time || post.createTime || 0);
    if (!ts) return '';
    return this.formatUnixTime(ts);
  }

  private formatAgreeText(post: Dict): string {
    const agree = post.agree as Dict | undefined;
    let count = 0;
    if (agree) count = Number(agree.agreeNum || agree.agree_num || agree.count || agree.num || 0);
    else count = Number(post.agreeNum || post.agree_num || post.likeNum || post.like_num || 0);
    if (count > 0) return this.formatCount(count);
    return '';
  }

  private getPostAgreed(post: Dict): boolean {
    const agree = post.agree as Dict | undefined;
    if (!agree) return false;
    return Number(agree.hasAgree || agree.has_agree || 0) === 1;
  }

  private getPostAgreeCount(post: Dict): number {
    const agree = post.agree as Dict | undefined;
    if (agree) return Number(agree.agreeNum || agree.agree_num || agree.count || agree.num || 0);
    return Number(post.agreeNum || post.agree_num || post.likeNum || post.like_num || 0);
  }

  private formatCount(n: number): string {
    if (n <= 0) return '';
    if (n >= 10000) return (n / 10000).toFixed(1) + 'w';
    return String(n);
  }

  private formatUnixTime(ts: number): string {
    if (!ts) return '';
    const now = Math.floor(Date.now() / 1000);
    const diff = now - ts;
    if (diff < 0) {
      const d = new Date(ts * 1000);
      const pad = (n: number) => n < 10 ? '0' + n : String(n);
      return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) +
        ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
    }
    if (diff < 60) return '刚刚';
    if (diff < 1800) return Math.floor(diff / 60) + '分钟前';
    const date = new Date(ts * 1000);
    const nowDate = new Date(now * 1000);
    const pad = (n: number) => n < 10 ? '0' + n : String(n);
    if (date.getFullYear() === nowDate.getFullYear() &&
        date.getMonth() === nowDate.getMonth() &&
        date.getDate() === nowDate.getDate()) {
      return pad(date.getHours()) + ':' + pad(date.getMinutes());
    }
    if (date.getFullYear() === nowDate.getFullYear()) {
      return pad(date.getMonth() + 1) + '-' + pad(date.getDate()) + ' ' + pad(date.getHours()) + ':' + pad(date.getMinutes());
    }
    return date.getFullYear() + '-' + pad(date.getMonth() + 1) + '-' + pad(date.getDate()) +
      ' ' + pad(date.getHours()) + ':' + pad(date.getMinutes());
  }

  private resolveSubAuthorName(sub: Dict): string {
    const a = sub.author as Dict;
    if (a?.name_show || a?.name) return String(a.name_show || a.name);
    if (sub.author_name) return String(sub.author_name);
    const authorId = Number(sub.author_id || (sub.author as Dict)?.id || 0);
    if (authorId && this._userMap.has(authorId)) {
      const user = this._userMap.get(authorId) as Dict;
      if (user?.name_show || user?.name) return String(user.name_show || user.name);
    }
    return '';
  }

  private resolveSubAuthorNameId(sub: Dict): string {
    const a = sub.author as Dict;
    if (a?.name) return '@' + String(a.name);
    const authorId = Number(sub.author_id || (sub.author as Dict)?.id || 0);
    if (authorId && this._userMap.has(authorId)) {
      const user = this._userMap.get(authorId) as Dict;
      if (user?.name) return '@' + String(user.name);
    }
    return '';
  }

  private resolveSubQuoteName(sub: Dict): string {
    if (sub.quote && (sub.quote as Dict)?.author_name) return String((sub.quote as Dict).author_name);
    return '';
  }

  private getSubContentText(contents: Dict[]): string {
    if (!contents || contents.length === 0) return '';
    const texts: string[] = [];
    for (const c of contents) {
      const t = Number(c.type);
      if (t === 2 || t === 6 || t === 7 || t === 9 || t === 10 || t === 11 || t === 12 || t === 13) {
        texts.push(String(c.c || c.text || ''));
      } else if (c.text) {
        texts.push(String(c.text));
      } else if (t === 1) texts.push('[图片]');
      else if (t === 3) texts.push('[视频]');
      else if (t === 4) texts.push('[音频]');
    }
    return texts.join('');
  }

  private getSubPreviewLine(sub: Dict): string {
    const name = this.resolveSubAuthorName(sub);
    const nameId = this.resolveSubAuthorNameId(sub);
    const content = this.getSubContentText(sub.content ? sub.content as Dict[] : []);
    const hasMedia = this.hasMediaContent(sub.content ? sub.content as Dict[] : []);
    const quote = this.resolveSubQuoteName(sub);
    const prefix = quote ? name + ' Reply ' + quote + ': ' + name + nameId : name + nameId;
    const suffix = content.length > 0 ? content : (hasMedia ? '[图片/视频]' : '');
    return prefix + ': ' + suffix;
  }

  private getShownSubPosts(post: Dict): Dict[] {
    const blockRepo = BlockRepository.getInstance();
    return this.extractSubPostList(post).filter((sub: Dict) => {
      const authorId = Number(sub.author_id || (sub.author as Dict)?.id || 0);
      if (authorId > 0 && blockRepo.isUserBlocked(authorId)) return false;
      return !blockRepo.isContentBlocked('', this.getSubContentText(sub.content ? sub.content as Dict[] : []));
    }).slice(0, 4);
  }

  private shouldShowMoreLink(post: Dict): boolean {
    const subs = this.extractSubPostList(post);
    const total = Number(post.sub_post_number || post.subPostNumber || subs.length);
    return total > 4;
  }

  private extractSubPostList(post: Dict): Dict[] {
    const raw = post.sub_post_list;
    if (!raw) return [];
    if (Array.isArray(raw)) return raw as Dict[];
    const w = raw as Dict;
    if (w.sub_post_list && Array.isArray(w.sub_post_list)) return w.sub_post_list as Dict[];
    return [];
  }

  private hasMediaContent(contents: Dict[]): boolean {
    if (!contents || !Array.isArray(contents)) return false;
    for (const c of contents) {
      const t = Number(c.type);
      if (t === 1 || t === 2 || t === 3 || t === 4) return true;
    }
    return false;
  }

  @Builder
  MetaDot() {
    Text('·')
      .fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textSecondary(this.isDark))
      .margin({ left: Math.round(3 * this.fontScale), right: Math.round(3 * this.fontScale) })
  }

  @Builder
  private postItem(post: Dict) {
    Column() {
      Row() {
        Avatar({ portrait: buildPortraitUrl(this.resolvePostAuthorPortrait(post)), avatarSize: 36, defaultName: this.resolvePostAuthorName(post) })
          .onClick(() => {
            if (Number(post.author_id || post.authorId || 0) > 0) {
              NavigationHelper.navigate('pages/user/UserProfilePage', { uid: String(post.author_id || post.authorId) });
            }
          }, 12)
        Column() {
          Row() {
            Text(this.resolvePostAuthorName(post))
              .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(darkenColor(this.primaryColor, this.isDark ? 0.25 : 0.55)).fontWeight(FontWeight.Bold)
              .onClick(() => {
                if (Number(post.author_id || post.authorId || 0) > 0) {
                  NavigationHelper.navigate('pages/user/UserProfilePage', { uid: String(post.author_id || post.authorId) });
                }
              }, 12)
            if (Number(post.author_id || post.authorId || 0) > 0 && Number(post.author_id || post.authorId || 0) === Number(this.threadData?.authorId || 0)) {
              Text('楼主').fontFamily(this.appFontFamily).fontSize(10).fontColor('#FF6B35').fontWeight(FontWeight.Bold)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor(blendWithBg('#FF6B35', 0.15, this.isDark))
                .borderRadius(10)
                .margin({ left: 6 })
            }
            if (this.getPostBawuRole(post) === 1) {
              Text('吧主').fontFamily(this.appFontFamily).fontSize(10).fontColor('#FFB800').fontWeight(FontWeight.Bold)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor(blendWithBg('#FFB800', 0.15, this.isDark))
                .borderRadius(10)
                .margin({ left: 6 })
            } else if (this.getPostBawuRole(post) === 2) {
              Text('小吧主').fontFamily(this.appFontFamily).fontSize(10).fontColor('#4477E0').fontWeight(FontWeight.Bold)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor(blendWithBg('#4477E0', 0.15, this.isDark))
                .borderRadius(10)
                .margin({ left: 6 })
            }
            if (this.resolvePostAuthorLevel(post) > 0) {
              Text('Lv.' + String(this.resolvePostAuthorLevel(post)))
                .fontFamily(this.appFontFamily).fontSize(Math.round(11 * this.fontScale)).fontColor(this.getLevelColor(this.resolvePostAuthorLevel(post))).fontWeight(FontWeight.Bold)
                .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                .backgroundColor(blendWithBg(this.getLevelColor(this.resolvePostAuthorLevel(post)), 0.15, this.isDark))
                .borderRadius(8).margin({ left: 6 })
            }
            if (this.resolvePostAuthorVipIcon(post)) {
              Image(this.resolvePostAuthorVipIcon(post))
                .width(Math.round(14 * this.fontScale)).height(Math.round(14 * this.fontScale))
                .objectFit(ImageFit.Contain).margin({ left: 4 })
            }
          }
          .width('100%')
          Row() {
            Text(this.formatPostTime(post))
              .fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textSecondary(this.isDark)).letterSpacing(1)
            if (post.floor) {
              this.MetaDot()
              Text(String(post.floor) + '楼')
                .fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textSecondary(this.isDark)).letterSpacing(1)
            }
            if (this.resolvePostAuthorIp(post)) {
              this.MetaDot()
              Text(this.resolvePostAuthorIp(post))
                .fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textSecondary(this.isDark)).letterSpacing(1)
            }
          }
          .width('100%')
          .margin({ top: 4 })
        }
        .margin({ left: 10 })
        .layoutWeight(1)
        Row() {
          if (this.getPostAgreeCount(post) > 0) {
            Text(this.formatCount(this.getPostAgreeCount(post)))
              .fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(this.getPostAgreed(post) ? '#FF4444' : textTertiary(this.isDark))
          }
          Image($r('app.media.ic_favorite')).width(Math.round(20 * this.fontScale)).height(Math.round(20 * this.fontScale)).fillColor(this.getPostAgreed(post) ? '#FF4444' : textTertiary(this.isDark)).margin({ left: 4 })
        }
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .onClick(() => this.toggleLikePost(post), 12)
        .padding({ right: 6 })
      }
      .alignItems(VerticalAlign.Center)
      .padding({ left: 12, right: 12, top: 6, bottom: 0 })
      .width('100%')

      if (post.content) {
        Column() {
          PbContentRender({ contents: post.content as Dict[], allImageUrls: this.allThreadImageUrls, allImageStartIndex: this.getImageStartForReplyPost(post), threadId: this.threadId, forumId: this.forumId, forumName: this.forumName })
            .padding({ left: 58, right: 6, top: 6, bottom: 0 })
            .onClick(() => {
              const name = this.resolvePostAuthorName(post);
              if (!AccountManager.getInstance().isLoggedIn()) { NavigationHelper.navigate('pages/login/LoginPage'); return; }
              this.replyPostId = Number(post.id || post.pid || 0);
              this.replyUserId = Number(post.author_id || post.authorId || (post.author as Dict)?.id || 0);
              this.replyHint = name ? '回复 ' + name : '';
              this.showReply = true;
              this.openReply();
              this.scrollToReplyTarget();
            }, 12)
        }
        .gesture(
          LongPressGesture({ repeat: false, duration: 500 })
            .onAction((event: GestureEvent) => {
              this.menuText = this.getPlainText(post.content as Dict[]);
              this.menuPostId = Number(post.id || post.pid || 0);
              this.menuPostAuthorId = Number(post.author_id || post.authorId || (post.author as Dict)?.id || 0);
              this.menuX = event.fingerList[0].globalX;
              this.menuY = event.fingerList[0].globalY;
              this.menuShow = true;
            })
        )
      }

      if (post.sub_post_list) {
        Column() {
          ForEach(this.getShownSubPosts(post), (sub: Dict, idx: number) => {
            Text() {
              Span(this.resolveSubAuthorName(sub) + (this.resolveSubAuthorNameId(sub).length > 0 ? this.resolveSubAuthorNameId(sub) : ''))
                .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(darkenColor(this.primaryColor, this.isDark ? 0.25 : 0.55)).fontWeight(FontWeight.Bold)
                .onClick(() => {
                  const uid = String((sub.author as Dict)?.id || sub.author_id || 0);
                  if (uid !== '0') {
                    NavigationHelper.navigate('pages/user/UserProfilePage', { uid: uid });
                  }
                })
              if (Number((sub.author as Dict)?.id || sub.author_id || 0) > 0 && Number((sub.author as Dict)?.id || sub.author_id || 0) === Number(this.threadData?.authorId || 0)) {
                Span(' 楼主')
                  .fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor('#FF6B35').fontWeight(FontWeight.Bold)
              }
              Span(': ')
              if ((sub.content as Dict[]) && (sub.content as Dict[]).length > 0) {
                ForEach(sub.content as Dict[], (item: Dict) => {
                  if (Number(item.type) === 0 && String(item.text || '').length > 0) {
                    Span(String(item.text))
                      .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(textPrimary(this.isDark))
                  } else if ((Number(item.type) === 2 || Number(item.type) === 6 || Number(item.type) === 7 ||
                              Number(item.type) === 9 || Number(item.type) === 10 || Number(item.type) === 11 ||
                              Number(item.type) === 12 || Number(item.type) === 13)) {
                    ImageSpan(PbContentRender.resolveEmojiId(String(item.id || item.text || item.c || '')).replace('https://', 'http://'))
                      .width(20).height(20).objectFit(ImageFit.Contain)
                      .verticalAlign(ImageSpanAlignment.CENTER)
                  } else if (Number(item.type) === 1 && PbContentRender.resolveImageSrc(item)) {
                    ImageSpan(PbContentRender.resolveImageSrc(item))
                      .width(72).height(72).objectFit(ImageFit.Contain)
                      .verticalAlign(ImageSpanAlignment.CENTER)
                  } else if (Number(item.type) === 1) {
                    Span('[图片]')
                      .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(textPrimary(this.isDark))
                  } else if (Number(item.type) === 3 || Number(item.type) === 5) {
                    Span('[视频]')
                      .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(textPrimary(this.isDark))
                  } else if (Number(item.type) === 4) {
                    Span('[音频]')
                      .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(textPrimary(this.isDark))
                  } else if (String(item.text || '').length > 0) {
                    Span(String(item.text))
                      .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(textPrimary(this.isDark))
                  }
                })
              } else if (this.hasMediaContent(sub.content ? sub.content as Dict[] : [])) {
                Span('[图片/视频]')
                  .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(textPrimary(this.isDark))
              }
            }
            .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).lineHeight(Math.round(22 * this.fontScale)).letterSpacing(0.5).textAlign(TextAlign.Start)
            .maxLines(8).textOverflow({ overflow: TextOverflow.Ellipsis }).wordBreak(WordBreak.BREAK_WORD)
            .width('100%').padding({ left: 12, right: 12, top: 0, bottom: 9 })
            .onClick(() => {
              NavigationHelper.navigate('pages/subposts/SubPostsPage', { threadId: String(this.threadId), postId: String(post.id || post.pid), forumId: String(this.forumId), forumName: this.forumName, lzId: String(this.threadData?.authorId || 0) });
            }, 12)
          })
          if (this.shouldShowMoreLink(post)) {
            Text('查看全部' + String(post.sub_post_number || post.subPostNumber || this.extractSubPostList(post).length) + '条回复')
              .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(textAccent(this.primaryColor, this.isDark)).fontWeight(FontWeight.Medium)
              .width('100%').textAlign(TextAlign.Start)
              .padding({ left: 12, top: 2, bottom: 8 })
              .onClick(() => {
                NavigationHelper.navigate('pages/subposts/SubPostsPage', { threadId: String(this.threadId), postId: String(post.id || post.pid), forumId: String(this.forumId), forumName: this.forumName, lzId: String(this.threadData?.authorId || 0) });
              }, 12)
          }
        }
        .backgroundColor(blendWithBg(this.primaryColor, 0.18, this.isDark, '#1E1E1E'))
        .borderRadius(6)
        .padding({ top: 8, bottom: 0 })
        .margin({ left: 58, right: 6, top: 7, bottom: 0 })
      }

    }
    .padding({ top: 0, bottom: 0 })
  }

  @Builder
  private MenuToggleBtn(label: string, checked: boolean, action: () => void) {
    Column() {
      Text(label).fontFamily(this.appFontFamily).fontSize(14 * this.fontScale).fontColor(checked ? '#FFFFFF' : textPrimary(this.isDark))
        .fontWeight(checked ? FontWeight.Bold : FontWeight.Regular)
        .width('100%').textAlign(TextAlign.Center)
    }
    .height(54)
    .backgroundColor(checked ? textAccent(this.primaryColor, this.isDark) : pageBg(this.isDark))
    .borderRadius(14)
    .margin({ left: 4, right: 4 })
    .onClick(() => { action(); })
  }

  @Builder
  private MenuListItem(label: string, action: () => void) {
    Row() {
      Text(label).fontFamily(this.appFontFamily).fontSize(16 * this.fontScale).fontColor(textPrimary(this.isDark)).padding({ left: 8 })
      Blank()
      Image($r('app.media.ic_arrow_back')).width(16).height(16).fillColor('#CCCCCC').rotate({ angle: 180 })
    }
    .width('100%').height(48)
    .onClick(() => { action(); })
  }

  @Builder
  private pollWidget(pollInfo: Dict) {
    Column() {
      Text(String(pollInfo.title || '投票'))
        .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontWeight(FontWeight.Bold)
      
      ForEach(Array.isArray(pollInfo.options) ? pollInfo.options as Dict[] : [], (opt: Dict, index: number) => {
        Row() {
          Text(String(opt.text || ''))
            .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale))
          Blank()
          Text(opt.num ? String(opt.num) + ' 票 ' : '')
            .fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textTertiary(this.isDark))
        }
        .width('100%')
        .padding(12)
        .backgroundColor(pageBg(this.isDark))
        .borderRadius(8)
        .margin({ top: 6 })
        .onClick(() => { promptAction.showToast({ message: '即将推出', duration: 1500 }); })
      })
    }
    .padding(16)
    .width('100%')
    .backgroundColor(cardBg(this.isDark))
    .borderRadius(8)
    .margin({ left: 12, right: 12, top: 8 })
  }

  private openReply(): void {
    if (!this.agreeToRisk) {
      PreferencesManager.getInstance().getBoolean('reply_risk_agreed', false).then((agreed: boolean) => {
        if (!agreed) {
          this.showRiskWarning = true;
        } else {
          this.agreeToRisk = true;
        }
      });
    }
  }

  private scrollToReplyTarget(): void {
    if (!this.showReply || this.replyPostId <= 0) return;
    const info = this._postPosMap.get(this.replyPostId);
    if (!info || info.h <= 0) return;
    const screenH = this.screenHeight > 0 ? this.screenHeight : 800;
    const panelTop = screenH - this.keyboardHeight - this.replyPanelH;
    const targetScreenY = panelTop - 16 - info.h;
    const targetScroll = Math.max(0, info.y - targetScreenY);
    const cur = this.scroller.currentOffset().yOffset;
    if (Math.abs(cur - targetScroll) > 3) {
      this.scroller.scrollTo({ xOffset: 0, yOffset: targetScroll, animation: { duration: 260, curve: Curve.EaseInOut } });
    }
  }

  private scheduleReplyScroll(delay: number): void {
    if (this._replyScrollTimer >= 0) {
      clearTimeout(this._replyScrollTimer);
    }
    this._replyScrollTimer = setTimeout(() => {
      this._replyScrollTimer = -1;
      this.scrollToReplyTarget();
    }, delay);
  }

  private async pickImages(): Promise<void> {
    try {
      const photoPicker = new picker.PhotoViewPicker();
      const result = await photoPicker.select({
        MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 9
      });
      if (result.photoUris && result.photoUris.length > 0) {
        const copied: string[] = [];
        for (const uri of result.photoUris) {
          const p = await this.copyToSandbox(uri, 'image');
          if (p) copied.push(p);
        }
        if (copied.length > 0) {
          this.selectedImageUris = copied;
        } else {
          promptAction.showToast({ message: '图片读取失败', duration: 1500 });
        }
      }
    } catch (e) {
      console.error('TiebaLite: pickImages error=' + String(e));
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
      const dest = ctx.cacheDir + '/reply_' + Date.now() + '_' + Math.floor(Math.random() * 100000) + (kind === 'video' ? '.mp4' : '.jpg');
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

  private async uploadImageAndGetId(uri: string): Promise<string> {
    try {
      const compressed = await compressImageToBuffer(uri);
      const buf = compressed.buffer;
      if (buf.byteLength <= 0) return '';

      const md5 = await MD5.hashBytes(new Uint8Array(buf));
      const fileName = uri.substring(uri.lastIndexOf('/') + 1) || 'image.jpg';
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
        console.error('TiebaLite: uploadImage no response');
        return '';
      }
      const errCode = raw.error_code || raw.errorCode || raw.no || '0';
      if (String(errCode) !== '0' && String(errCode) !== '300000') {
        console.error('TiebaLite: uploadImage failed code=' + errCode + ' result=' + JSON.stringify(raw).substring(0, 200));
        return '';
      }
      const picId = String(raw.pic_id || raw.picId || raw.resource_id || raw.resourceId || '');
      if (picId) {
        const info = (raw.info || raw.pic_info || raw.picInfo || raw.data) as Record<string, Object> || ({} as Record<string, Object>);
        const bigPic = (info.big_pic || info.bigPic || info.origin_pic || info.originPic) as Record<string, Object> || ({} as Record<string, Object>);
        const w = String(bigPic.width || info.fullpic_width || info.width || compressed.width);
        const h = String(bigPic.height || info.fullpic_height || info.height || compressed.height);
        this.imageUploadResults.push({
          picId: picId,
          width: w,
          height: h
        });
        return picId;
      }
      const info2 = (raw.info || raw.pic_info || raw.picInfo || raw.data) as Record<string, Object> || ({} as Record<string, Object>);
      const infoId = String(info2.pic_id || info2.picId || '');
      const bigPic2 = (info2.big_pic || info2.bigPic || info2.origin_pic || info2.originPic) as Record<string, Object> || ({} as Record<string, Object>);
      const w2 = String(bigPic2.width || info2.fullpic_width || compressed.width);
      const h2 = String(bigPic2.height || info2.fullpic_height || compressed.height);
      const finalId = infoId || picId;
      if (!finalId) {
        console.error('TiebaLite: uploadImage no pic_id result=' + JSON.stringify(raw).substring(0, 200));
        return '';
      }
      this.imageUploadResults.push({
        picId: finalId,
        width: w2,
        height: h2
      });
      return finalId;
    } catch (e) {
      console.error('TiebaLite: uploadImageAndGetId error=' + String(e));
      return '';
    }
  }

  @Builder
  EmojiPanel() {
    Scroll() {
      Grid() {
        ForEach(EMOTICONS, (emoji: EmojiItem) => {
          GridItem() {
            Image(emojiUrl(emoji.id))
              .width(28).height(28).objectFit(ImageFit.Contain)
              .onClick(() => {
                this.richController.addImageSpan(emojiUrl(emoji.id), {
                  offset: this.richController.getCaretOffset(),
                  imageStyle: { size: [20, 20] }
                });
                this.replyContent = richEditorToText(this.richController);
                this.updateReplyEditorH();
                this.showEmojiPanel = false;
              })
          }
        })
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
      .rowsGap(6).columnsGap(6)
      .width('100%').padding(8)
    }
      .scrollBar(BarState.Off)
    .height(220).width('100%')
    .backgroundColor(blendWithBg(this.primaryColor, 0.20, this.isDark, '#1E1E1E'))
    .borderRadius(12)
    .edgeEffect(EdgeEffect.Spring)
  }

  private async loadLocalLikeState(): Promise<void> {
    try {
      const prefs = PreferencesManager.getInstance();
      const liked = await prefs.getString('liked_tid_' + this.threadId, '');
      if (liked === '1') this.liked = true;
      else if (liked === '0') this.liked = false;
      const countStr = await prefs.getString('liked_count_tid_' + this.threadId, '');
      const c = Number(countStr);
      if (countStr !== '' && !isNaN(c) && c >= 0) this.likeCount = c;
      const collected = await prefs.getString('collected_tid_' + this.threadId, '');
      if (collected === '1') this.isCollected = true;
      else if (collected === '0') this.isCollected = false;
    } catch (e) {
      console.error('TiebaLite: loadLocalLikeState error=' + String(e));
    }
  }

  private persistLikeState(): void {
    void PreferencesManager.getInstance().putString('liked_tid_' + this.threadId, this.liked ? '1' : '0').catch(() => {});
  }

  private persistLikeCount(): void {
    void PreferencesManager.getInstance().putString('liked_count_tid_' + this.threadId, String(this.likeCount)).catch(() => {});
  }

  private bumpLikeVersion(): void {
    try { AppStorage.SetOrCreate('likedVersion', (AppStorage.Get<number>('likedVersion') ?? 0) + 1); } catch (e) {}
  }

  private persistCollectState(): void {
    void PreferencesManager.getInstance().putString('collected_tid_' + this.threadId, this.isCollected ? '1' : '0').catch(() => {});
  }

  private async toggleLike(): Promise<void> {
    if (!AccountManager.getInstance().isLoggedIn()) return;
    try {
      if (this.liked) {
        await this.repo.dislikePost(this.threadId, 0);
        this.liked = false;
        this.likeCount = Math.max(0, this.likeCount - 1);
      } else {
        await this.repo.likePost(this.threadId, 0);
        this.liked = true;
        this.likeCount++;
      }
      this.persistLikeState();
      this.persistLikeCount();
      this.bumpLikeVersion();
      this.repo.clearThreadCache();
    } catch (e) {
      promptAction.showToast({ message: '操作失败，请重试', duration: 1500 });
    }
  }

  private async toggleLikePost(post: Dict): Promise<void> {
    if (!AccountManager.getInstance().isLoggedIn()) return;
    const postId = Number(post.id || post.pid || 0);
    if (!postId) return;
    try {
      const agree = post.agree as Dict | undefined;
      const hasAgreed = agree ? Number((agree as Dict).hasAgree || (agree as Dict).has_agree || 0) === 1 : false;
      if (hasAgreed) {
        await this.repo.dislikePost(this.threadId, postId);
        if (agree) {
          (agree as Dict).hasAgree = 0;
          const n = Number(agree.agreeNum || agree.agree_num || 0);
          if (n > 0) { agree.agreeNum = n - 1; agree.agree_num = n - 1; }
        }
      } else {
        await this.repo.likePost(this.threadId, postId);
        if (agree) {
          (agree as Dict).hasAgree = 1;
          const n = Number(agree.agreeNum || agree.agree_num || 0);
          agree.agreeNum = n + 1;
          agree.agree_num = n + 1;
        }
      }
      this.posts = [...this.posts];
    } catch (e) {
      promptAction.showToast({ message: '操作失败，请重试', duration: 1500 });
    }
  }

  private shareThread(): void {
    const url = 'https://tieba.baidu.com/p/' + this.threadId;
    const title: string = String(this.threadData?.title || '');
    try {
      const shareData: systemShare.SharedData = new systemShare.SharedData({
        utd: utd.UniformDataType.HYPERLINK,
        content: url,
        title: title
      });
      const controller: systemShare.ShareController = new systemShare.ShareController(shareData);
      const context = getContext(this) as common.UIAbilityContext;
      controller.show(context, {
        previewMode: systemShare.SharePreviewMode.DEFAULT,
        selectionMode: systemShare.SelectionMode.SINGLE
      }).catch((_err: Error) => {
        this.copyToClipboard(url);
        promptAction.showToast({ message: '链接已复制到剪贴板', duration: 1500 });
      });
    } catch (_e) {
      this.copyToClipboard(url);
      promptAction.showToast({ message: '链接已复制到剪贴板', duration: 1500 });
    }
  }

  private copyLink(): void {
    const link = 'https://tieba.baidu.com/p/' + this.threadId;
    this.copyToClipboard(link);
  }

  private reportThread(): void {
    promptAction.showToast({ message: '即将推出', duration: 1500 });
  }

  private async deleteOwnThread(): Promise<void> {
    const account = AccountManager.getInstance().getCurrentAccountSync();
    if (!account) {
      promptAction.showToast({ message: '未登录', duration: 1500 });
      return;
    }
    if (this._firstPostId === 0) {
      promptAction.showToast({ message: '删除失败：无法获取帖子信息', duration: 2000 });
      return;
    }
    try {
      await this.repo.deleteThread(this.forumId, this.forumName, this.threadId);
      promptAction.showToast({ message: '删除成功', duration: 1500 });
      router.back();
    } catch (e) {
      console.error('TiebaLite: deleteOwnThread error=' + String(e));
      promptAction.showToast({ message: '删除失败', duration: 2000 });
    }
  }

  private async toggleCollect(): Promise<void> {
    if (!AccountManager.getInstance().isLoggedIn()) {
      NavigationHelper.navigate('pages/login/LoginPage');
      return;
    }
    try {
      if (this.isCollected) {
        await ThreadStoreRepository.getInstance().removeStore(this.threadId);
        this.isCollected = false;
        this.collectCount = Math.max(0, this.collectCount - 1);
      } else {
        await ThreadStoreRepository.getInstance().addStore(this.threadId, this._firstPostId);
        this.isCollected = true;
        this.collectCount++;
      }
      this.persistCollectState();
      this.repo.clearThreadCache();
    } catch (e) {
      console.error('TiebaLite: ToggleCollect error code=' + String((e as Dict).code) + ' msg=' + String((e as Dict).msg));
      promptAction.showToast({ message: '操作失败，请重试', duration: 1500 });
    }
  }

  private showJumpDialog(): void {
    this.jumpPageText = '';
    this.showJump = true;
  }

  private async doJumpPage(): Promise<void> {
    const p = parseInt(this.jumpPageText);
    if (isNaN(p) || p < 1) {
      promptAction.showToast({ message: '请输入有效的页码', duration: 1500 });
      return;
    }
    this.showJump = false;
    this.page = p;
    this.hasMore = true;
    await this.loadThread(p);
  }

  private buildUserMap(userList: Dict[]): Map<number, Dict> {
    const map: Map<number, Dict> = new Map();
    if (!userList || !Array.isArray(userList)) return map;
    for (const u of userList) {
      if (u) map.set(Number(u.id || u.user_id), u);
    }
    return map;
  }

  private extractThreadInfo(data: Dict): Dict | null {
    if (!data) return null;
    const rawList = data.user_list || (data.data as Dict)?.user_list || [];
    const userList: Dict[] = Array.isArray(rawList) ? rawList as Dict[] : [];
    const userMap: Map<number, Dict> = this.buildUserMap(userList);
    const threadData = (data.data as Dict) || data;
    let thread: Dict = (threadData.thread || data.thread) as Dict;
    if (!thread) {
      const rawPosts = threadData.post_list || data.post_list || [];
      const posts: Dict[] = Array.isArray(rawPosts) ? rawPosts as Dict[] : [];
      this._firstPostId = posts.length > 0 ? Number((posts[0] as Dict).id || (posts[0] as Dict).pid || (posts[0] as Dict).post_id || 0) : 0;
      console.info('TiebaLite: _firstPostId set to ' + this._firstPostId + ' from posts[0].id=' + (posts.length > 0 ? (posts[0] as Dict).id : 'none'));
      const firstPost = posts.length > 0 ? posts[0] as Dict : null;
      if (firstPost) {
        const authorId = Number(firstPost.author_id || firstPost.authorId || 0);
        const author = authorId ? userMap.get(authorId) : null;
        const firstPostAuthor = firstPost.author as Dict || null;
        thread = {
          title: firstPost.title || '',
          authorId: authorId,
          author_id: authorId,
          author_name: author?.name_show || author?.nameShow || author?.name || firstPost.author_name || (firstPostAuthor?.name_show as string) || (firstPostAuthor?.nameShow as string) || (firstPostAuthor?.name as string) || '',
          author_portrait: author?.portrait || firstPost.author_portrait || (firstPostAuthor?.portrait as string) || '',
          author_level: author?.level_id || author?.levelId || ((author?.user_growth as Dict)?.level_id) || 0,
          create_time: firstPost.time || firstPost.create_time || firstPost.createTime || '',
          content: (firstPost.content as Dict[]) || []
        } as Dict;
      }
    }
    if (!thread) return null;

    let author: Dict | null = thread.author as Dict || null;
    if ((!author || !author.name) && thread.author_id) {
      const authorFromMap = userMap.get(Number(thread.author_id));
      if (authorFromMap) author = authorFromMap;
    }

    const info: Dict = {} as Dict;
    info.title = String(thread.title || '');
    info.authorName = String(author?.name_show || author?.nameShow || author?.name || thread.author_name || '');
    info.authorPortrait = String(author?.portrait || thread.author_portrait || '');
    info.authorLevel = author?.level_id || author?.levelId || ((author?.user_growth as Dict)?.level_id) || thread.author_level || 0;
    info.authorIp = author?.ip_address || author?.ipAddress || thread.author_ip || '';
    info.authorId = Number(author?.id || author?.user_id || thread.author_id || thread.authorId || 0);
    if (author) info.author = author;
    info.createTime = String(thread.createTime || thread.create_time || '');
    info.replyNum = thread.replyNum || thread.reply_num || 0;
    const getArray = (v: Object): Dict[] => Array.isArray(v) ? v as Dict[] : [];
    const originThread = (thread.originThreadInfo as Dict) || (thread.origin_thread_info as Dict) || null;
    const rawPosts = threadData.post_list || data.post_list || [];
    const posts: Dict[] = Array.isArray(rawPosts) ? rawPosts as Dict[] : [];
    if (this._firstPostId === 0) this._firstPostId = posts.length > 0 ? Number((posts[0] as Dict).id || (posts[0] as Dict).pid || (posts[0] as Dict).post_id || 0) : 0;
    const firstPostContent: Dict[] = (posts.length > 0 ? (posts[0] as Dict)?.content : null) as Dict[] || [];
    const contentArr = getArray(firstPostContent) || getArray(originThread?.content) || getArray(thread.firstPostContent) || getArray(thread.first_post_content) || getArray(thread.content) || getArray(threadData.content) || [];
    info.content = contentArr;
    info.pollInfo = thread.pollInfo || null;
    info.forumName = String(thread.forumName || thread.forum_name || '');
    const firstPostData = posts.length > 0 ? posts[0] as Dict : null;
    if (firstPostData) {
      const agree = firstPostData.agree as Dict || {};
      this.likeCount = Number(agree.agreeNum || agree.agree_num || agree.count || agree.num || firstPostData.agreeNum || firstPostData.agree_num || 0);
      this.collectCount = Number(firstPostData.favoNum || firstPostData.favo_num || firstPostData.collectNum || 0);
      this.liked = Number(agree.hasAgree || agree.has_agree || 0) === 1;
      const threadData2 = (data.data as Dict) || data;
      const threadObj: Dict = (threadData2.thread || data.thread) as Dict || {};
      const _hf = firstPostData.has_favo; const _hf2 = firstPostData.hasFavo;
      const _if = firstPostData.is_favorited; const _if2 = firstPostData.isFavorited;
      const _hs = firstPostData.has_store; const _hs2 = firstPostData.hasStore;
      const _is = firstPostData.is_stored; const _is2 = firstPostData.isStored;
      const _thf = threadObj.has_favo; const _thf2 = threadObj.hasFavo;
      const _tif = threadObj.is_favorited; const _tif2 = threadObj.isFavorited;
      const _ths = threadObj.has_store; const _ths2 = threadObj.hasStore;
      const _tis = threadObj.is_stored; const _tis2 = threadObj.isStored;
      const _tcs = threadObj.collect_status; const _tcs2 = threadObj.collectStatus; const _fpcs = firstPostData.collect_status; const _fpcs2 = firstPostData.collectStatus;
      console.info('TiebaLite: isCollectedFields hf=' + _hf + '/' + _hf2 + ' if=' + _if + '/' + _if2 + ' hs=' + _hs + '/' + _hs2 + ' is=' + _is + '/' + _is2 + ' thf=' + _thf + '/' + _thf2 + ' tif=' + _tif + '/' + _tif2 + ' ths=' + _ths + '/' + _ths2 + ' tis=' + _tis + '/' + _tis2 + ' tcs=' + _tcs + '/' + _tcs2 + ' fpcs=' + _fpcs + '/' + _fpcs2);
      console.info('TiebaLite: firstPostData keys=' + Object.keys(firstPostData).join(','));
      // 服务端收藏状态字段：任一存在即以服务端为准（1=已收藏 0=未收藏），
      // 修复：取消收藏后重新进入帖子页仍显示点亮（原先只认 1 不认 0）
      const collectCandidates: Object[] = [
        firstPostData.has_favo, firstPostData.hasFavo,
        firstPostData.is_favorited, firstPostData.isFavorited,
        firstPostData.has_store, firstPostData.hasStore,
        firstPostData.is_stored, firstPostData.isStored,
        threadObj.has_favo, threadObj.hasFavo,
        threadObj.is_favorited, threadObj.isFavorited,
        threadObj.has_store, threadObj.hasStore,
        threadObj.is_stored, threadObj.isStored,
        threadObj.collect_status, threadObj.collectStatus,
        firstPostData.collect_status, firstPostData.collectStatus
      ];
      let collectPresent: boolean = false;
      let collectValue: number = 0;
      for (let i = 0; i < collectCandidates.length; i++) {
        const candidate: Object = collectCandidates[i];
        if (candidate !== undefined && candidate !== null) {
          collectPresent = true;
          collectValue = Number(candidate);
          break;
        }
      }
      if (collectPresent) {
        this.isCollected = collectValue === 1;
      }
    }
    const threadAgree = thread.agree as Dict || {};
    if (threadAgree.agreeNum || threadAgree.agree_num || threadAgree.count) {
      this.likeCount = Number(threadAgree.agreeNum || threadAgree.agree_num || threadAgree.count || 0);
    }
    return info;
  }

  private extractPosts(data: Dict, pageNum?: number): Dict[] {
    if (!data) return [];
    const raw = data.post_list || (data.data as Dict)?.post_list || [];
    const posts: Dict[] = Array.isArray(raw) ? raw as Dict[] : [];
    const p = pageNum ?? this.page;
    const slice = (posts.length > 0 && p === 1) ? posts.slice(1) : posts;
    const blockRepo = BlockRepository.getInstance();
    return slice.filter((post: Dict) => {
      const authorId = Number(post.author_id || post.authorId || (post.author as Dict)?.id || 0);
      if (authorId > 0 && blockRepo.isUserBlocked(authorId)) return false;
      return !blockRepo.isContentBlocked('', this.getPlainText(post.content as Dict[]));
    });
  }

  private isLastPage(data: Dict): boolean {
    const pageInfo = (data.page as Dict) || (data.data as Dict)?.page as Dict || {};
    const totalPage = Number(pageInfo.totalPage || pageInfo.total_page || 0);
    if (totalPage > 0) return this.page >= totalPage;
    const raw = data.post_list || (data.data as Dict)?.post_list || [];
    const posts: object[] = Array.isArray(raw) ? raw as object[] : [];
    return posts.length < 30;
  }

  private async loadMore(): Promise<void> {
    if (this.loadingMore) return;
    this.loadingMore = true;
    const nextPage = this.sortType === 1 ? this.page - 1 : this.page + 1;
    if (nextPage < 1) { this.hasMore = false; this.loadingMore = false; return; }
    try {
      const data: Dict = await this.repo.loadThreadPage(this.threadId, nextPage, this.seeLz, this.sortType);
      this.collectManagerInfo(data);
      const rawUserList = data.user_list || (data.data as Dict)?.user_list || [];
      if (Array.isArray(rawUserList)) {
        for (const u of rawUserList as Dict[]) {
          if (u) { const uid = Number(u.id || u.user_id); if (uid > 0 && !this._userMap.has(uid)) this._userMap.set(uid, u); }
        }
      }
      const more: Dict[] = this.extractPosts(data, nextPage);
      if (more.length === 0) { this.hasMore = false; this.loadingMore = false; return; }
      this.posts = [...this.posts, ...more];
      this.page = nextPage;
      this.hasMore = !this.isLastPage(data);
    } catch (e) {
      this.hasMore = false;
    }
    this.loadingMore = false;
  }

  private reload(): void {
    this.page = 1;
    this.loadThread();
  }

  @Builder
  actionBarRow(fixed: boolean) {
    Row() {
      Text('回复 ' + String(this.threadData?.replyNum || this.posts.length))
        .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(this.seeLz ? textTertiary(this.isDark) : textPrimary(this.isDark))
        .fontWeight(this.seeLz ? FontWeight.Regular : FontWeight.Bold).margin({ right: 6 })
        .onClick(() => { if (this.seeLz) { this.seeLz = false; this.reload(); } })
      Text('|')
        .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark)).margin({ right: 6 })
      Text('只看楼主')
        .fontFamily(this.appFontFamily).fontSize(Math.round(13 * this.fontScale)).fontColor(this.seeLz ? textAccent(this.primaryColor, this.isDark) : textTertiary(this.isDark))
        .fontWeight(this.seeLz ? FontWeight.Bold : FontWeight.Normal)
        .onClick(() => { if (!this.seeLz) { this.seeLz = true; this.reload(); } })
      Blank()
      Text('正序').fontFamily(this.appFontFamily).fontSize(Math.round(13 * this.fontScale))
        .fontColor(this.sortType === 0 ? textAccent(this.primaryColor, this.isDark) : textTertiary(this.isDark))
        .fontWeight(this.sortType === 0 ? FontWeight.Bold : FontWeight.Normal)
        .padding({ right: 6 })
        .onClick(() => { this.sortType = 0; this.reload(); })
      Text('|')
        .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark)).padding({ right: 6 })
      Text('倒序').fontFamily(this.appFontFamily).fontSize(Math.round(13 * this.fontScale))
        .fontColor(this.sortType === 1 ? textAccent(this.primaryColor, this.isDark) : textTertiary(this.isDark))
        .fontWeight(this.sortType === 1 ? FontWeight.Bold : FontWeight.Normal)
        .onClick(() => { this.sortType = 1; this.reload(); })
    }
    .padding({ left: 16, right: 16 })
    .height(44)
    .width('100%')
    .border({ width: { bottom: fixed ? 1 : 0 }, color: blendWithBg(this.primaryColor, 0.15, this.isDark, '#1E1E1E') })
  }

  onBackPress(): boolean {
    if (this.showReply) {
      this.showReply = false;
      this.showEmojiPanel = false;
      this.showRiskWarning = false;
      this.selectedImageUris = [];
      this.imageUploadResults = [];
      this.replyPostId = 0;
      this.replyUserId = 0;
      return true;
    }
    NavigationHelper.markBack();
    return false;
  }

  private handleBarTouch(event: TouchEvent): void {
    const touch = event.touches[0];
    if (event.type === TouchType.Down) {
      this.touchX = touch.x;
      this.touchY = touch.y;
      this.liquidAlpha = 1;
      this.liquidR = 0;
      this.drawLiquid();
      this.startRippleExpand();
    } else if (event.type === TouchType.Move) {
      this.touchX = touch.x;
      this.touchY = touch.y;
      this.drawLiquid();
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.liquidR = 0;
      this.liquidAlpha = 0;
      this.drawLiquid();
    }
  }

  onGripSideChanged(): void {
    if (!GripDetector.isEnabled()) {
      if (this.fabLeft) this.fabLeft = false;
      return;
    }
    if (this.gripSide === -1 && !this.fabLeft) {
      this.switchFabSide(true);
    } else if (this.gripSide === 1 && this.fabLeft) {
      this.switchFabSide(false);
    }
  }

  private switchFabSide(toLeft: boolean): void {
    if (this.fabLeft === toLeft) return;
    if (this.fabTimer !== -1) { clearTimeout(this.fabTimer); }
    if (!this.showScrollTop) {
      this.fabLeft = toLeft;
      return;
    }
    const wasVisible = this.showScrollTop;
    animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
      this.showScrollTop = false;
    });
    this.fabTimer = setTimeout(() => {
      this.fabTimer = -1;
      this.fabLeft = toLeft;
      if (wasVisible) {
        animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
          this.showScrollTop = true;
        });
      }
    }, 250);
  }

  private startRippleExpand(): void {
    let r = 0;
    const step = (): void => {
      r += 4;
      this.liquidR = Math.min(r, 60);
      this.drawLiquid();
      if (this.liquidR < 60) {
        setTimeout(step, 16);
      }
    };
    setTimeout(step, 16);
  }

  private drawLiquid(): void {
    const ctx = this.liquidCtx;
    if (!ctx) return;
    const w = this.barWidth;
    const h = 50;
    ctx.clearRect(0, 0, w, h);
    if (this.liquidAlpha < 0.01 || this.liquidR < 1) return;
    ctx.save();
    ctx.globalAlpha = this.liquidAlpha;
    const parsed = this.parseHexColor(this.primaryColor);
    const r = parsed[0];
    const g = parsed[1];
    const b = parsed[2];
    const R = this.liquidR;
    ctx.translate(this.touchX, this.touchY);
    ctx.scale(1.2, 0.8);
    ctx.rotate(0.15);
    const gradient = ctx.createRadialGradient(0, 0, 0, 0, 0, R);
    gradient.addColorStop(0, `rgba(${r},${g},${b},0.80)`);
    gradient.addColorStop(0.3, `rgba(${r},${g},${b},0.35)`);
    gradient.addColorStop(0.6, `rgba(${r},${g},${b},0.15)`);
    gradient.addColorStop(1, `rgba(${r},${g},${b},0)`);
    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.arc(0, 0, R, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  private parseHexColor(hex: string): number[] {
    const h = hex.replace('#', '');
    return [parseInt(h.substring(0, 2), 16), parseInt(h.substring(2, 4), 16), parseInt(h.substring(4, 6), 16)];
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

