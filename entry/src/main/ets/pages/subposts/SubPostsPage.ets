import router from '@ohos.router';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard';
import display from '@ohos.display';
import window from '@ohos.window';
import { KeyboardAvoidMode } from '@ohos.arkui.UIContext';
import inputMethod from '@ohos.inputMethod';
import PbPageRepository from '../../core/repository/PbPageRepository';
import AddPostRepository from '../../core/repository/AddPostRepository';
import BlockRepository from '../../core/repository/BlockRepository';
import ThreadStoreRepository from '../../core/repository/ThreadStoreRepository';
import AccountManager from '../../core/auth/AccountManager';
import PbContentRender from '../../components/PbContentRender';
import Avatar from '../../components/Avatar';
import LoadingState from '../../components/LoadingState';
import ErrorState from '../../components/ErrorState';
import GearLoading from '../../components/GearLoading';
import { Dict } from '../../core/types/Dict';
import { getStr, blendWithBg, blendWithWhite, darkenColor, pageBg, cardBg, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor, KEYBOARD_IME_EXTRA_VP, primaryContainer, onPrimaryContainer } from '../../core/utils/DataHelper';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';
import { GripDetector } from '../../core/utils/GripDetector';
import PreferencesManager from '../../core/storage/PreferencesManager';
import EmojiImage from '../../components/EmojiImage';
import { registerEmoji, getEmojiIdFromMap, richEditorToText } from '../../components/EmojiManager';

function buildPortraitUrl(portrait: string): string {
  if (!portrait) return '';
  if (portrait.startsWith('http://') || portrait.startsWith('https://')) return portrait;
  const q = portrait.indexOf('?');
  const path = q >= 0 ? portrait.substring(0, q) : portrait;
  return 'http://tb.himg.baidu.com/sys/portraitn/item/' + path;
}

function getEmojiUrl(item: Dict): string {
  const directUrl = String(item.bsrc || item.src || item.icon || item.url || item.picUrl || item.thumbnail || item.c || '');
  if (directUrl.startsWith('https://')) return directUrl;
  if (directUrl.startsWith('http://')) return 'https://' + directUrl.substring(7);
  if (directUrl.startsWith('//')) return 'https:' + directUrl;
  const textId = String(item.text || '').trim();
  const name = String(item.c || '').trim();
  if (textId && name && textId !== name) {
    registerEmoji(name, textId);
  }
  const rawId = String(item.id || item.text || item.c || '').trim();
  if (!rawId) return '';
  return getEmojiUrlById(rawId);
}

function getSpacedEmojiId(rawId: string): string {
  const id = rawId.replace(/[[\]【】「」『』《》（）()<>{}]/g, '').trim();
  const m = id.match(/^#?\s*emot(?:ion|icon)\s*[:：]?\s*(\d+)$/);
  return m ? 'image_emoticon' + m[1] : '';
}

function getEmojiUrlById(rawId: string): string {
  const id = rawId.replace(/[[\]【】「」『』《》（）()<>{}]/g, '').trim();
  if (!id) return '';
  const knownPrefixes = ['image_emoticon', 'image_emotion', 'shoubai_emoji', 'tsj_emoji', 'tb_emoji', 'emoji_', 'bai_emoji', 'new_emoticon', 'tieba_emoji', 'emotion_', 'emoticon_'];
  if (/^\d+$/.test(id)) return 'https://static.tieba.baidu.com/tb/editor/images/client/image_emoticon' + id + '.png';
  const spaced = getSpacedEmojiId(id);
  if (spaced) return 'https://static.tieba.baidu.com/tb/editor/images/client/' + spaced + '.png';
  if (knownPrefixes.some(p => id.startsWith(p))) return 'https://static.tieba.baidu.com/tb/editor/images/client/' + id + '.png';
  const mapped = getEmojiIdFromMap(id);
  if (mapped) return 'https://static.tieba.baidu.com/tb/editor/images/client/' + mapped + '.png';
  const encoded = encodeURIComponent(id);
  return 'https://static.tieba.baidu.com/tb/editor/images/client/' + encoded + '.png';
}

function isEmojiText(text: string): boolean {
  const id = text.replace(/[[\]【】「」『』《》（）()<>{}]/g, '').trim();
  if (!id) return false;
  const knownPrefixes = ['image_emoticon', 'image_emotion', 'shoubai_emoji', 'tsj_emoji', 'tb_emoji', 'emoji_', 'bai_emoji', 'new_emoticon', 'tieba_emoji', 'emotion_', 'emoticon_'];
  if (knownPrefixes.some(p => id.startsWith(p))) return true;
  if (/^\d+$/.test(id)) return true;
  if (getEmojiIdFromMap(id)) return true;
  if (getSpacedEmojiId(id)) return true;
  return false;
}

class EmojiItem {
  id: string;
  name: string;
  constructor(id: string, name: string) { this.id = id; this.name = name; }
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
struct SubPostsPage {
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  @StorageLink('gripSide') @Watch('onGripSideChanged') gripSide: number = 0;
  @StorageLink('fabRadius') fabRadius: number = 60;
  reduceEffects: boolean = false;
  @StorageLink('fontScale') fontScale: number = 1.06;
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @State threadId: number = 0;
  @State postId: number = 0;
  @State forumId: number = 0;
  @State forumName: string = '';

  @State parentPost: Dict | null = null;
  @State subPosts: Dict[] = [];
  @State page: number = 1;
  @State hasMore: boolean = true;
  @State loading: boolean = true;
  @State loadingMore: boolean = false;
  @State error: string = '';
  @State replyContent: string = '';
  private richController: RichEditorController = new RichEditorController();
  @State showReply: boolean = false;
  @State showEmojiPanel: boolean = false;
  @State replyHint: string = '';
  @State subPostId: number = 0;
  @State replyUserId: number = 0;
  @State replyPortrait: string = '';
  @State showRiskWarning: boolean = false;
  @State riskNeverAgainChecked: boolean = false;
  @State agreeToRisk: boolean = false;
  @State fabVisible: boolean = true;
  @State fabLeft: boolean = false;
  private fabTimer: number = -1;
  private fabScroller: Scroller = new Scroller();
  private lastFabScrollY: number = 0;
  @State menuShow: boolean = false;
  @State menuPostId: number = 0;
  @State menuPostAuthorId: number = 0;
  @State menuText: string = '';
  @State menuX: number = 0;
  @State menuY: number = 0;
  @State screenWidth: number = 360;
  @State screenHeight: number = 780;
  @State keyboardHeight: number = 0;
  @State kbExtra: number = AppStorage.Get<number>('replyKbExtraV2') ?? KEYBOARD_IME_EXTRA_VP;
  @State replyEditorH: number = 46;

  private repo: PbPageRepository = PbPageRepository.getInstance();
  private addRepo: AddPostRepository = AddPostRepository.getInstance();
  private lzId: number = 0;
  private floorOwnerId: number = 0;
  private _userMap: Map<number, Dict> = new Map();
  private _pendingSub: Dict | null = null;
  private _win: window.Window | null = null;
  private _density: number = 1;

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
    if (!this.fabVisible) {
      this.fabLeft = toLeft;
      return;
    }
    const wasVisible = this.fabVisible;
    animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
      this.fabVisible = false;
    });
    this.fabTimer = setTimeout(() => {
      this.fabTimer = -1;
      this.fabLeft = toLeft;
      if (wasVisible) {
        animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
          this.fabVisible = true;
        });
      }
    }, 250);
  }
  private _winH0: number = 0;
  private _winGapVp: number = 0;
  private _lastKbHpx: number = 0;
  private _kbAdjustAt: number = 0;

  aboutToAppear(): void {
    try { this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE); } catch (e) {}
    const params = router.getParams() as Record<string, string>;
    this.threadId = parseInt(params?.threadId || '0');
    this.postId = parseInt(params?.postId || '0');
    this.forumId = parseInt(params?.forumId || '0');
    this.forumName = params?.forumName || '';
    const lzIdParam = parseInt(params?.lzId || '0');
    if (lzIdParam > 0) {
      this.lzId = lzIdParam;
    }
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
    this.onGripSideChanged();
    void BlockRepository.getInstance().ensureLoaded();
    void this.loadSubPosts();
  }

  onIsDarkChange(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
  }

  onPageShow(): void {
    AppStorage.SetOrCreate('previewActiveId', '');
    AppStorage.SetOrCreate('previewActiveVisible', false);
    const t = AppStorage.get<number>('previewClaimTick') || 0;
    AppStorage.SetOrCreate<number>('previewClaimTick', t + 1);
    this.reduceEffects = AppStorage.get<boolean>('reduceEffects') === true;
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
    this.bindKeyboardListener();
  }

  onPageHide(): void {
    AppStorage.SetOrCreate('previewActiveId', '');
    AppStorage.SetOrCreate('previewActiveVisible', false);
    this.unbindKeyboardListener();
  }

  private bindKeyboardListener(): void {
    try {
      window.getLastWindow(getContext(this)).then((win: window.Window) => {
        try { win.off('keyboardHeightChange'); win.off('avoidAreaChange'); win.off('keyboardWillShow'); win.off('keyboardDidShow'); win.off('keyboardDidHide'); } catch (_e) {}
        this._win = win;
        try {
          this._winH0 = win.getWindowProperties().windowRect.height;
          this._winGapVp = Math.max(0, this.screenHeight - this._winH0 / this._density);
        } catch (_e) {}
        console.info('TiebaLite: sub kb win0px=' + this._winH0 + ' dispHvp=' + this.screenHeight.toFixed(1) + ' winGapVp=' + this._winGapVp.toFixed(1));
        const readKbAvoidHpx = (): number => {
          try {
            const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_KEYBOARD);
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
            console.info('TiebaLite: sub kb exact topPx=' + topPx + ' win=' + winH + ' avoidPx=' + avoidHpx + ' extra=' + this.kbExtra + ' corr=' + kbCorr + ' offset=' + this.keyboardHeight.toFixed(1));
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
            console.info('TiebaLite: sub kb delta hPx=' + hPx + ' avoidPx=' + avoidHpx + ' extra=' + this.kbExtra + ' offset=' + this.keyboardHeight.toFixed(1));
            this.scheduleReplyScroll(300);
          } catch (_e) {}
        };
        const logKbInfo = (tag: string, info: window.KeyboardInfo): void => {
          try {
            const b: window.Rect | undefined = info?.beginRect;
            const r: window.Rect | undefined = info?.endRect;
            console.info('TiebaLite: sub ' + tag + ' begin(h=' + (b ? (b.height / this._density).toFixed(1) : '?') + ' top=' + (b ? (b.top / this._density).toFixed(1) : '?') + ') end(h=' + (r ? (r.height / this._density).toFixed(1) : '?') + ' top=' + (r ? (r.top / this._density).toFixed(1) : '?') + ') endPx=' + (r ? r.height : -1) + ' dispHvp=' + this.screenHeight.toFixed(1));
          } catch (_e) {}
        };
        win.on('keyboardWillShow', (info: window.KeyboardInfo): void => {
          logKbInfo('kbWillShow', info);
          try {
            const r: window.Rect | undefined = info?.endRect;
            if (r && r.height > 0) {
              this._lastKbHpx = r.height;
              applyKbTop(r.top);
            }
          } catch (_e) {}
        });
        win.on('keyboardDidShow', (info: window.KeyboardInfo): void => {
          logKbInfo('kbDidShow', info);
          try {
            const r: window.Rect | undefined = info?.endRect;
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
        win.on('keyboardDidHide', (info: window.KeyboardInfo): void => {
          logKbInfo('kbDidHide', info);
          this._lastKbHpx = 0;
          this.keyboardHeight = 0;
          this.scheduleReplyScroll(300);
        });
        win.on('keyboardHeightChange', (h: number) => { applyKbDelta(h); });
        win.on('avoidAreaChange', () => {
          try {
            const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_KEYBOARD);
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

  private handleFabScroll(): void {
    const y = this.fabScroller.currentOffset().yOffset;
    const delta = y - this.lastFabScrollY;
    this.lastFabScrollY = y;
    if (Math.abs(delta) > 2000 || Math.abs(delta) < 0.5) return;
    if (delta > 5) {
      if (this.fabVisible) {
        animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => { this.fabVisible = false; });
      }
    } else if (delta < -5) {
      if (!this.fabVisible) {
        animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => { this.fabVisible = true; });
      }
    }
  }

  private closeReplyWindow(): void {
    this.showReply = false;
    this.replyContent = '';
    try { this.richController.deleteSpans(); } catch (_e) {}
    this.showEmojiPanel = false;
    this.replyHint = '';
    this.subPostId = 0;
    this.replyUserId = 0;
    this.replyPortrait = '';
    try { inputMethod.getController().stopInputSession(); } catch (_e) {}
  }

  private async sendReply(): Promise<void> {
    if (this.replyContent.length === 0) return;
    try {
      let contentToSend: string = this.replyContent;
      if (this.subPostId > 0 && this.replyPortrait.length > 0) {
        const replyName = this.replyHint.replace('回复 ', '');
        contentToSend = '回复 #(reply, ' + this.replyPortrait + ', ' + replyName + ') :' + this.replyContent;
      }
      await this.addRepo.replyToThread(this.forumId, this.forumName, this.threadId, contentToSend, this.postId > 0 ? this.postId : undefined, this.subPostId > 0 ? this.subPostId : undefined, this.replyUserId > 0 ? this.replyUserId : undefined);
      const account = AccountManager.getInstance().getCurrentAccountSync();
      const myName = account?.nickname || '';
      const author: Dict = { id: account?.uid || 0, name: myName, nameShow: myName, portrait: account?.portrait || '' };
      const contentItem: Dict = { type: 0, text: this.replyContent };
      const agree: Dict = { agreeNum: 0, hasAgree: 0 };
      const newSub: Dict = {
        id: 0,
        author: author,
        content: [contentItem],
        time: Math.floor(Date.now() / 1000),
        agree: agree
      };
      if (this.subPostId > 0 && this.replyUserId > 0) {
        const quote: Dict = { authorName: this.replyHint.replace('回复 ', '') };
        newSub['quote'] = quote;
      }
      this.subPosts = [...this.subPosts, newSub];
      this._pendingSub = newSub;
      this.closeReplyWindow();
      void this.loadSubPosts();
      promptAction.showToast({ message: '回复已发送', duration: 1500 });
    } catch (e) {
      promptAction.showToast({ message: '回复失败', duration: 2000 });
    }
  }

  async loadSubPosts(): Promise<void> {
    this.loading = true;
    this.error = '';
    this.page = 1;
    try {
      const data: Dict = await this.repo.loadFloorPage(this.threadId, this.postId, this.forumId, this.page);
      this.parentPost = this.extractParentPost(data);
      this.subPosts = this.extractSubPosts(data);
      const pending: Dict | null = this._pendingSub;
      if (pending) {
        const pendingText = this.buildSubContent(pending);
        const found = this.subPosts.some((s: Dict) => this.buildSubContent(s) === pendingText);
        if (found) {
          this._pendingSub = null;
        } else {
          this.subPosts = [...this.subPosts, pending];
        }
      }
      this.hasMore = this.checkHasMore(data);
      const rawUserList = data.user_list || (data.data as Dict)?.user_list || [];
      if (Array.isArray(rawUserList)) {
        for (const u of rawUserList as Dict[]) {
          if (u) { const uid = Number(u.id || u.user_id); if (uid > 0 && !this._userMap.has(uid)) this._userMap.set(uid, u); }
        }
      }
      if (this.parentPost) {
        const pa = this.parentPost.author as Dict;
        if (pa) {
          this.floorOwnerId = Number(pa.id || 0);
        }
      }
      if (this.lzId <= 0) {
        const threadNode = (data.thread as Dict) || ((data.data as Dict)?.thread as Dict) || null;
        if (threadNode) {
          const ta = threadNode.author as Dict;
          this.lzId = Number(threadNode.author_id || threadNode.authorId || ta?.id || ta?.user_id || 0);
        }
      }
      if (!this.forumName) {
        this.forumName = getStr(data, 'forum_name', 'forumName', 'fname') || '';
      }
    } catch (e) {
      this.error = (e as Dict)?.msg as string || (e as Dict)?.message as string || '加载失败';
    } finally {
      this.loading = false;
    }
  }

  build() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor(pageBg(this.isDark))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      Column() {
      Row() {
          Image($r('app.media.ic_arrow_back')).width(22).height(22).fillColor(textPrimary(this.isDark))
            .onClick(() => router.back())
          Text('子回复')
            .fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontWeight(FontWeight.Bold)
            .fontColor(textPrimary(this.isDark))
            .margin({ left: 12 })
          Blank()
        }
        .padding(12)
        .width('100%')
        .backgroundColor(pageBg(this.isDark))
        .backdropBlur(40)

        if (this.loading) {
          LoadingState({ message: '加载中...' })
        } else if (this.error.length > 0) {
          ErrorState({ message: this.error, onRetryAction: (): void => { void this.loadSubPosts(); } })
        } else {
          Scroll(this.fabScroller) {
            Column() {
              if (this.parentPost) {
                if (this.isParentPostBlocked()) {
                  Column() {
                    Text('该楼层内容已被屏蔽').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark))
                      .width('100%').padding(24).textAlign(TextAlign.Center)
                  }
                  .width('100%')
                } else {
                  this.parentPostItem(this.parentPost)
                }
              }
              Column() {
                Divider().height(32).color(this.isDark ? 'rgba(255,255,255,0.35)' : 'rgba(0,0,0,0.35)').width('100%').margin({ top: 6, bottom: 6 }).strokeWidth(2)
              }
              .width('100%').backgroundColor(pageBg(this.isDark)).padding({ left: 12, right: 12 })

              ForEach(this.subPosts, (sub: Dict, index: number) => {
                this.subPostItem(sub)
              })

              if (this.hasMore && this.subPosts.length > 0) {
                Row() {
                  if (this.loadingMore) {
                    GearLoading({ gearSize: 24, color: darkenColor(this.primaryColor, 0.2), text: '加载中...' })
                  } else {
                    Text('加载更多...')
                      .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark))
                      .onClick(() => { void this.loadMore(); }, 12)
                  }
                }
                .width('100%').justifyContent(FlexAlign.Center).padding(16)
              }
            }
            .width('100%')
            .padding({ bottom: 0 })
            .backgroundColor(pageBg(this.isDark))
            .alignItems(HorizontalAlign.Start)
            .justifyContent(FlexAlign.Start)
          }
            .scrollBar(BarState.Off)
          .width('100%')
          .layoutWeight(1)
          .align(Alignment.Top)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
          .backgroundColor(pageBg(this.isDark))
          .edgeEffect(EdgeEffect.Spring)
          .onDidScroll(() => { this.handleFabScroll(); })
        }

        if (!this.showReply) {
          Stack() {
            Image($r('app.media.ic_edit')).width(20).height(20).fillColor(onPrimaryContainer(this.isDark))
          }
            .width(48).height(48)
            .backgroundColor(primaryContainer(this.isDark))
            .borderRadius(24 * this.fabRadius / 100)
            .shadow({ radius: 8, color: shadowColor(this.isDark), offsetY: 4 })
            .position({ bottom: 32, right: 24 })
            .translate({ x: this.fabVisible ? (this.fabLeft ? -(this.screenWidth - 96) : 0) : (this.fabLeft ? -(this.screenWidth - 96) - 96 : 96) })
            .hitTestBehavior(this.fabVisible ? HitTestMode.Default : HitTestMode.None)
            .onClick(async () => {
              if (!AccountManager.getInstance().isLoggedIn()) { NavigationHelper.navigate('pages/login/LoginPage'); return; }
              if (!this.agreeToRisk) {
                const prefsAgreed = await PreferencesManager.getInstance().getBoolean('reply_risk_agreed', false);
                if (prefsAgreed) {
                  this.agreeToRisk = true;
                } else {
                  this.showRiskWarning = true;
                }
              }
              this.replyHint = '回复 ' + this.getAuthorName(this.parentPost?.author as Dict);
              this.subPostId = 0;
              this.replyUserId = Number((this.parentPost?.author as Dict)?.id || 0);
              this.replyPortrait = '';
              this.showReply = true;
            }, 12)
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      if (this.showReply) {
        Column().width('100%').height('100%').onClick(() => { this.closeReplyWindow(); })
      }

      if (this.showReply && this.showRiskWarning) {
        Column() {
          Row() {
            Text('回复').fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold)
            Blank()
            Button('取消').fontColor(textSecondary(this.isDark)).backgroundColor('transparent')
              .onClick(() => { this.showRiskWarning = false; this.closeReplyWindow(); })
          }.padding(12).width('100%')
          Column() {
            Row() {
              Image($r('app.media.ic_warning')).width(18).height(18).fillColor('#FF4444')
              Text('风险提示').fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FF4444').margin({ left: 4 })
            }
            Text('第三方客户端可能导致账号被封禁，请谨慎使用！')
              .fontFamily(this.appFontFamily).fontSize(13).fontColor(textSecondary(this.isDark)).margin({ top: 8 })
            Row() {
              Checkbox().select(this.riskNeverAgainChecked)
                .onChange((v: boolean) => { this.riskNeverAgainChecked = v; })
              Text('不再提示').fontFamily(this.appFontFamily).fontSize(13).fontColor(textSecondary(this.isDark)).margin({ left: 6 })
            }
            .margin({ top: 12 })
            .onClick(() => { this.riskNeverAgainChecked = !this.riskNeverAgainChecked; })
          }
          .padding(16)
          .width('100%')
          .backgroundColor('#FFF0F0')
          .borderRadius(12)
          Button('同意并继续').width('100%').height(44)
            .backgroundColor(this.primaryColor).fontColor('#FFFFFF').borderRadius(22).margin({ top: 12 })
            .onClick(() => {
              if (this.riskNeverAgainChecked) {
                PreferencesManager.getInstance().putBoolean('reply_risk_agreed', true);
              }
              this.agreeToRisk = true;
              this.showRiskWarning = false;
            })
        }.padding(16).width('100%').backgroundColor(blendWithBg(this.primaryColor, 0.15, this.isDark)).position({ bottom: 0 })
      } else if (this.showReply) {
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
            .padding(12)
            .onReady(() => { this.richController.setTypingStyle({ fontSize: 16, fontColor: textPrimary(this.isDark) }); })
            .onIMEInputComplete(() => { this.replyContent = richEditorToText(this.richController); this.updateReplyEditorH(); })
            .onDeleteComplete(() => { this.replyContent = richEditorToText(this.richController); this.updateReplyEditorH(); })
            .onPaste(() => { this.replyContent = richEditorToText(this.richController); this.updateReplyEditorH(); })
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
            Blank()
            Text(String(this.replyContent.length) + '/10000').fontFamily(this.appFontFamily).fontSize(12).fontColor(textSecondary(this.isDark)).margin({ right: 8 })
Text('发送')
              .width(64).height(26).textAlign(TextAlign.Center)
              .backgroundColor(this.replyContent.length > 0 ? blendWithWhite(this.primaryColor, 0.35) : blendWithWhite(this.primaryColor, 0.25))
              .fontColor(this.replyContent.length > 0 ? '#0B2E6C' : '#8B96B4')
              .fontSize(15).fontWeight(FontWeight.Bold).borderRadius(12)
              .onClick(() => {
                if (Date.now() - this._kbAdjustAt < 600) return;
                if (this.replyContent.length > 0) {
                  this.sendReply();
                }
              })
              .gesture(
                LongPressGesture({ repeat: false, duration: 500 })
                  .onAction(() => { this._kbAdjustAt = Date.now(); this.adjustKbExtra(-10); })
              )
          }.width('100%').padding({ top: 4, bottom: 0 })

          if (this.showEmojiPanel) {
            Stack() {
              Column()
                .width('100%').height(220)
                .onClick(() => { this.showEmojiPanel = false; })
              this.EmojiPanel()
            }
            .width('100%')
          }
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 0 }).width('100%').backgroundColor(cardBg(this.isDark)).borderRadius(16)
        .position({ bottom: this.keyboardHeight > 0 ? this.keyboardHeight : -this._winGapVp })
      }

      if (this.menuShow) {
        Column() {
          Column() {
            this.MenuItem('复制', () => { this.copyToClipboard(this.menuText); this.menuShow = false; })
            Divider().height(0.5).color(dividerColor(this.isDark))
            if (AccountManager.getInstance().getCurrentAccountSync()?.uid === this.menuPostAuthorId && this.menuPostAuthorId > 0) {
              this.MenuItem('删除', () => { void this.deletePost(this.menuPostId); this.menuShow = false; })
              Divider().height(0.5).color(dividerColor(this.isDark))
            }
            this.MenuItem('举报', () => { this.reportPost(this.menuPostId); this.menuShow = false; })
            Divider().height(0.5).color(dividerColor(this.isDark))
            this.MenuItem('收藏到此楼', () => { this.bookmarkPost(this.menuPostId); this.menuShow = false; })
          }
          .width(140)
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
    .align(Alignment.TopStart)
    .backgroundColor(pageBg(this.isDark)).expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
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

  @Builder
  SubDot() {
    Text('·')
      .fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textSecondary(this.isDark))
      .margin({ left: Math.round(3 * this.fontScale), right: Math.round(3 * this.fontScale) })
  }

  @Builder
  private parentPostItem(post: Dict) {
    Column() {
      Row() {
        Avatar({ portrait: buildPortraitUrl(String((post.author as Dict)?.portrait || '')), avatarSize: 40, defaultName: String(this.getAuthorName(post.author as Dict)) })
          .onClick(() => {
            NavigationHelper.navigate('pages/user/UserProfilePage', { uid: String(this.getAuthorId(post.author as Dict)) })
          })
        Column() {
          Row() {
            Text(this.getAuthorName(post.author as Dict))
              .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(darkenColor(this.primaryColor, this.isDark ? 0.25 : 0.55)).fontWeight(FontWeight.Bold)
            if (this.getLevel(post.author as Dict) > 0) {
              Text('Lv.' + this.getLevel(post.author as Dict))
                .fontFamily(this.appFontFamily).fontSize(Math.round(11 * this.fontScale)).fontColor(this.getLevelColor(this.getLevel(post.author as Dict))).fontWeight(FontWeight.Bold)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor(blendWithBg(this.getLevelColor(this.getLevel(post.author as Dict)), 0.15, this.isDark))
                .borderRadius(10)
                .margin({ left: 6 })
            }
            Blank()
          }
          .width('100%')
          Row() {
            Text(this.formatSubTime(Number(post.createTime || post.create_time || post.time || 0)))
              .fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textSecondary(this.isDark)).letterSpacing(1)
            if (post.floor) {
              this.SubDot()
              Text(String(post.floor) + '楼')
                .fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textSecondary(this.isDark)).letterSpacing(1)
            }
            if (this.resolvePostIp(post)) {
              this.SubDot()
              Text(this.resolvePostIp(post))
                .fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textSecondary(this.isDark)).letterSpacing(1)
            }
          }
          .margin({ top: 2 })
        }
        .margin({ left: 8 })
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Column() {
          Row() {
            if ((post.agree as Dict)?.agreeNum || (post.agree as Dict)?.agree_num) {
              Text(String((post.agree as Dict)?.agreeNum || (post.agree as Dict)?.agree_num || '') + ' ')
                .fontFamily(this.appFontFamily).fontSize(Math.round(11 * this.fontScale)).fontColor(textTertiary(this.isDark))
            }
            Image($r('app.media.ic_favorite')).width(18).height(18).fillColor(textTertiary(this.isDark))
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
        }
        .justifyContent(FlexAlign.Center)
      }
      .padding({ left: 12, right: 12, top: 12 })
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (post.content) {
        Column() {
          PbContentRender({ contents: post.content as Dict[], threadId: this.threadId, forumId: this.forumId, forumName: this.forumName })
            .padding({ left: 60, right: 12 })
        }
        .gesture(
          LongPressGesture({ repeat: false, duration: 500 })
            .onAction((event?: GestureEvent) => {
              this.menuText = this.buildSubContent(post);
              this.menuPostId = Number(post.id || post.pid || 0);
              this.menuPostAuthorId = Number(post.author_id || post.authorId || (post.author as Dict)?.id || 0);
              if (event && event.fingerList && event.fingerList.length > 0) {
                this.menuX = event.fingerList[0].globalX;
                this.menuY = event.fingerList[0].globalY;
              }
              this.menuShow = true;
            })
        )
      }

    }
    .width('100%')
    .backgroundColor(pageBg(this.isDark))
  }

  @Builder
  private subPostItem(sub: Dict) {
    Column() {
      Row() {
        Avatar({ portrait: buildPortraitUrl(this.getAuthorPortrait(sub)), avatarSize: 40, defaultName: this.getAuthorName(sub.author as Dict) })
          .onClick(() => {
            NavigationHelper.navigate('pages/user/UserProfilePage', { uid: String(this.getAuthorId(sub.author as Dict)) })
          })
        Column() {
          Row() {
            Text(this.getAuthorName(sub.author as Dict))
              .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(darkenColor(this.primaryColor, this.isDark ? 0.25 : 0.55)).fontWeight(FontWeight.Bold)
            if (this.getLevel(sub.author as Dict) > 0) {
              Text('Lv.' + this.getLevel(sub.author as Dict))
                .fontFamily(this.appFontFamily).fontSize(Math.round(11 * this.fontScale)).fontColor(this.getLevelColor(this.getLevel(sub.author as Dict))).fontWeight(FontWeight.Bold)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor(blendWithBg(this.getLevelColor(this.getLevel(sub.author as Dict)), 0.15, this.isDark))
                .borderRadius(10)
                .margin({ left: 6 })
            }
            if (this.getAuthorId(sub.author as Dict) === this.floorOwnerId && this.floorOwnerId > 0) {
              Text('层主').fontFamily(this.appFontFamily).fontSize(Math.round(10 * this.fontScale)).fontColor('#4CAF50').fontWeight(FontWeight.Bold)
                .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                .backgroundColor(blendWithBg('#4CAF50', 0.15, this.isDark))
                .borderRadius(999)
                .border({ width: 1, color: blendWithBg('#4CAF50', 0.5, this.isDark) })
                .margin({ left: 4 })
            } else if (this.getAuthorId(sub.author as Dict) === this.lzId && this.lzId > 0) {
              Text('楼主').fontFamily(this.appFontFamily).fontSize(Math.round(10 * this.fontScale)).fontColor('#FF6B35').fontWeight(FontWeight.Bold)
                .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                .backgroundColor(blendWithBg('#FF6B35', 0.15, this.isDark))
                .borderRadius(999)
                .border({ width: 1, color: blendWithBg('#FF6B35', 0.5, this.isDark) })
                .margin({ left: 4 })
            }
            if (this.getSubBawuRole(sub) === 1) {
              Text('吧主').fontFamily(this.appFontFamily).fontSize(Math.round(10 * this.fontScale)).fontColor('#FFB800').fontWeight(FontWeight.Bold)
                .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                .backgroundColor(blendWithBg('#FFB800', 0.15, this.isDark))
                .borderRadius(999)
                .border({ width: 1, color: blendWithBg('#FFB800', 0.5, this.isDark) })
                .margin({ left: 4 })
            } else if (this.getSubBawuRole(sub) === 2) {
              Text('小吧主').fontFamily(this.appFontFamily).fontSize(Math.round(10 * this.fontScale)).fontColor('#4477E0').fontWeight(FontWeight.Bold)
                .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                .backgroundColor(blendWithBg('#4477E0', 0.15, this.isDark))
                .borderRadius(999)
                .border({ width: 1, color: blendWithBg('#4477E0', 0.5, this.isDark) })
                .margin({ left: 4 })
            }
            Blank()
          }
          .width('100%')
          Text(this.formatSubTime(Number(sub.createTime || sub.create_time || sub.time || 0)))
            .fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textSecondary(this.isDark)).letterSpacing(1).margin({ top: 2 })
        }
        .margin({ left: 8 })
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Column() {
          Row() {
            if (this.getAgreeCount(sub) > 0) {
              Text(String(this.getAgreeCount(sub)) + ' ')
                .fontFamily(this.appFontFamily).fontSize(Math.round(11 * this.fontScale)).fontColor(textTertiary(this.isDark))
            }
            Image($r('app.media.ic_favorite')).width(16).height(16).fillColor(textTertiary(this.isDark)).opacity(this.getAgreed(sub) ? 1 : 0.5)
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => this.agreeSubPost(Number(sub.id || 0)), 12)
      }
      .padding({ left: 12, right: 12, top: 0 })
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (sub.content) {
        Column() {
          Text() {
            ForEach(sub.content as Dict[], (item: Dict) => {
                if (Number(item.type) === 0) {
                  if (String(item.text || item.c || '') && isEmojiText(String(item.text || item.c || '')) && getEmojiUrlById(String(item.text || item.c || ''))) {
                    ImageSpan(getEmojiUrlById(String(item.text || item.c || '')).replace('https://', 'http://'))
                      .width(20).height(20).objectFit(ImageFit.Contain)
                      .verticalAlign(ImageSpanAlignment.CENTER)
                  } else if (String(item.text || item.c || '')) {
                    Span(String(item.text || item.c || ''))
                      .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(textPrimary(this.isDark))
                  }
                } else if (Number(item.type) === 2 || Number(item.type) === 6 || Number(item.type) === 7 || Number(item.type) === 9 || Number(item.type) === 10 || Number(item.type) === 11 || Number(item.type) === 12 || Number(item.type) === 13) {
                  if (getEmojiUrl(item)) {
                    ImageSpan(getEmojiUrl(item).replace('https://', 'http://'))
                      .width(20).height(20).objectFit(ImageFit.Contain)
                      .verticalAlign(ImageSpanAlignment.CENTER)
                  } else if (item.text || item.c) {
                    Span(String(item.text || item.c || ''))
                      .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(textPrimary(this.isDark))
                  }
                } else if (Number(item.type) === 1 && PbContentRender.resolveImageSrc(item)) {
                  ImageSpan(PbContentRender.resolveImageSrc(item))
                    .width(120).height(120).objectFit(ImageFit.Contain)
                    .verticalAlign(ImageSpanAlignment.CENTER)
                } else if (Number(item.type) === 1 || Number(item.type) === 3 || Number(item.type) === 20) {
                  Span('[图片]')
                    .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(textPrimary(this.isDark))
                } else if (Number(item.type) === 5) {
                  Span('[视频]')
                    .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(textPrimary(this.isDark))
                } else if (item.text || item.c) {
                  if (isEmojiText(String(item.text || item.c || '')) && getEmojiUrlById(String(item.text || item.c || ''))) {
                    ImageSpan(getEmojiUrlById(String(item.text || item.c || '')).replace('https://', 'http://'))
                      .width(20).height(20).objectFit(ImageFit.Contain)
                      .verticalAlign(ImageSpanAlignment.CENTER)
                  } else {
                    Span(String(item.text || item.c || ''))
                      .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(textPrimary(this.isDark))
                  }
                }
              })
            }
            .fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).lineHeight(Math.round(24 * this.fontScale)).letterSpacing(0.4).textAlign(TextAlign.Start).width('100%')
          if (this.getQuoteName(sub)) {
            Text('回复 @' + this.getQuoteName(sub))
              .fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor('#4477E0').lineHeight(Math.round(18 * this.fontScale))
              .padding({ top: 2 })
              .onClick(async () => {
                if (!AccountManager.getInstance().isLoggedIn()) { NavigationHelper.navigate('pages/login/LoginPage'); return; }
                if (!this.agreeToRisk) {
                  const prefsAgreed = await PreferencesManager.getInstance().getBoolean('reply_risk_agreed', false);
                  if (prefsAgreed) {
                    this.agreeToRisk = true;
                  } else {
                    this.showRiskWarning = true;
                  }
                }
                this.replyHint = '回复 ' + this.getQuoteName(sub);
                this.subPostId = Number(sub.id || sub.pid || 0);
                this.replyUserId = Number((sub.author as Dict)?.id || sub.author_id || 0);
                this.replyPortrait = String((sub.author as Dict)?.portrait || '');
                this.showReply = true;
              }, 12)
          }
        }
        .width('100%').padding({ left: 60, right: 12 })
        .onClick(async () => {
          if (!AccountManager.getInstance().isLoggedIn()) { NavigationHelper.navigate('pages/login/LoginPage'); return; }
          if (!this.agreeToRisk) {
            const prefsAgreed = await PreferencesManager.getInstance().getBoolean('reply_risk_agreed', false);
            if (prefsAgreed) {
              this.agreeToRisk = true;
            } else {
              this.showRiskWarning = true;
            }
          }
          this.replyHint = '回复 ' + this.getAuthorName(sub.author as Dict);
          this.subPostId = Number(sub.id || sub.pid || 0);
          this.replyUserId = Number((sub.author as Dict)?.id || sub.author_id || 0);
          this.replyPortrait = String((sub.author as Dict)?.portrait || '');
          this.showReply = true;
        }, 12)
        .gesture(
          LongPressGesture({ repeat: false, duration: 500 })
            .onAction((event?: GestureEvent) => {
              this.menuText = this.buildSubContent(sub);
              this.menuPostId = Number(sub.id || 0);
              this.menuPostAuthorId = Number((sub.author as Dict)?.id || sub.author_id || 0);
              if (event && event.fingerList && event.fingerList.length > 0) {
                this.menuX = event.fingerList[0].globalX;
                this.menuY = event.fingerList[0].globalY;
              }
              this.menuShow = true;
            })
        )
      }

      Divider().height(4).color(this.isDark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.2)').width('100%').margin({ left: 60, right: 12, top: 11, bottom: 11 })
    }
    .width('100%')
    .backgroundColor(pageBg(this.isDark))
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

  private scheduleReplyScroll(_ms: number): void {
  }

  private getMenuAdjustedX(): number {
    const menuWidth = 140;
    const gap = 5;
    if (this.menuX < this.screenWidth / 2) {
      return Math.max(gap, this.menuX + gap);
    } else {
      return Math.min(this.screenWidth - menuWidth - gap, this.menuX - menuWidth - gap);
    }
  }

  private getMenuAdjustedY(): number {
    const menuHeight = 160;
    const minGap = 4;
    if (this.menuY < this.screenHeight / 2) {
      return Math.max(minGap, this.menuY);
    } else {
      return Math.min(this.screenHeight - menuHeight - minGap, this.menuY - menuHeight);
    }
  }

  @Builder
  MenuItem(label: string, action: () => void) {
    Row() {
      Text(label).fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(textPrimary(this.isDark))
    }
    .width('100%').height(44).padding({ left: 16, right: 16 })
    .onClick(() => { action(); })
    .backgroundColor(cardBg(this.isDark))
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
    const url = 'https://tieba.baidu.com/p/' + this.threadId + '?pid=' + postId;
    NavigationHelper.navigate('pages/webview/WebViewPage', { url: url, title: '举报' });
  }

  private async deletePost(postId: number): Promise<void> {
    try {
      await this.repo.deletePost(this.forumId, '', this.threadId, postId);
      promptAction.showToast({ message: '已删除', duration: 1000 });
      void this.loadSubPosts();
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

  private buildSubContent(sub: Dict): string {
    const contents = sub.content as Dict[];
    if (!contents || !Array.isArray(contents)) return '';
    let text = '';
    for (const c of contents) {
      const t = Number(c.type);
      if (t === 0) {
        text += String(c.text || '');
      } else if (t === 4) {
        const md5 = String(c.voiceMD5 || c.voice_md5 || c.voiceMd5 || '');
        if (md5.length > 0) {
          text += '[Voice]' + String(c.text || '');
        } else {
          text += String(c.text || '');
        }
      } else if (t === 1) {
        text += '[Image]';
      } else if (t === 2 || t === 6 || t === 7 || t === 9 || t === 10 || t === 11 || t === 12 || t === 13) {
        text += String(c.c || c.text || '');
      } else if (t === 3) {
        text += '[Video]';
      } else {
        text += String(c.text || '');
      }
    }
    return text;
  }

  private getAuthorName(author: Dict): string {
    if (!author) return '';
    const name = String(author.nameShow || author.name_show || author.name || '');
    if (name) return name;
    const uid = Number(author.id || 0);
    if (uid > 0 && this._userMap.has(uid)) {
      const u = this._userMap.get(uid) as Dict;
      return String(u.nameShow || u.name_show || u.name || '');
    }
    return '';
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

  private getAuthorPortrait(sub: Dict): string {
    const a = sub.author as Dict;
    if (a?.portrait) return String(a.portrait);
    if (a) {
      const uid = Number(a.id || 0);
      if (uid > 0 && this._userMap.has(uid)) {
        const u = this._userMap.get(uid) as Dict;
        if (u.portrait) return String(u.portrait);
      }
    }
    return '';
  }

  private getLevel(author: Dict): number {
    if (!author) return 0;
    return Number(author.level_id || author.levelId || 0);
  }

  private getAuthorId(author: Dict): number {
    if (!author) return 0;
    return Number(author.id || 0);
  }

  private resolvePostIp(p: Dict): string {
    if (!p) return '';
    const author = p.author as Dict;
    if (author && author.ip_address) return String(author.ip_address);
    const authorId = Number(p.author_id || p.authorId || this.getAuthorId(author));
    if (authorId > 0 && this._userMap.has(authorId)) {
      const u = this._userMap.get(authorId) as Dict;
      if (u && u.ip_address) return String(u.ip_address);
    }
    return '';
  }

  private getSubBawuRole(sub: Dict): number {
    const author = sub.author as Dict;
    if (!author || typeof author !== 'object') return 0;
    const bazhu = Number(author.is_bazhu || author.isBazhu || 0);
    const bawu = Number(author.is_bawu || author.isBawu || 0);
    if (bazhu === 1) return 1;
    if (bawu === 1) return String(author.bawu_type || '') === 'manager' ? 1 : 2;
    return 0;
  }

  private getAgreed(sub: Dict): boolean {
    if (!sub) return false;
    const a = sub.agree as Dict;
    if (!a) return false;
    return Number(a.hasAgree || a.has_agree || 0) === 1;
  }

  private getAgreeCount(sub: Dict): number {
    if (!sub) return 0;
    if (sub.agreeNum) return Number(sub.agreeNum);
    if (sub.agree_num) return Number(sub.agree_num);
    const a = sub.agree as Dict;
    if (a) return Number(a.agreeNum || a.agree_num || 0);
    return 0;
  }

  private getQuoteName(sub: Dict): string {
    const q = sub.quote as Dict;
    if (q) {
      const n = String(q.author_name || q.authorName || '');
      if (n.length > 0) return n;
    }
    return '';
  }

  private formatSubTime(ts: number): string {
    if (!ts) return '';
    const d = new Date(ts * 1000);
    const pad = (n: number) => n < 10 ? '0' + n : String(n);
    return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) +
      ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
  }

  private async agreeSubPost(subPostId: number): Promise<void> {
    if (!AccountManager.getInstance().isLoggedIn()) return;
    try {
      const sub = this.subPosts.find((s: Dict) => Number(s.id || 0) === subPostId);
      const agree = sub?.agree as Dict | undefined;
      const hasAgreed = agree ? Number(agree.hasAgree || agree.has_agree || 0) === 1 : false;
      if (hasAgreed) {
        await this.repo.dislikePost(this.threadId, subPostId);
        if (agree) {
          agree.hasAgree = 0;
          const n = Number(agree.agreeNum || agree.agree_num || 0);
          if (n > 0) { agree.agreeNum = n - 1; agree.agree_num = n - 1; }
        }
      } else {
        await this.repo.likePost(this.threadId, subPostId);
        if (agree) {
          agree.hasAgree = 1;
          const n = Number(agree.agreeNum || agree.agree_num || 0);
          agree.agreeNum = n + 1;
          agree.agree_num = n + 1;
        }
      }
      this.subPosts = [...this.subPosts];
    } catch (e) {
      promptAction.showToast({ message: '操作失败，请重试', duration: 1500 });
    }
  }

  private extractParentPost(data: Dict): Dict | null {
    if (!data) return null;
    return (data.post || (data.data as Dict)?.post || null) as Dict | null;
  }

  private isParentPostBlocked(): boolean {
    if (!this.parentPost) return false;
    const blockRepo = BlockRepository.getInstance();
    const authorId = Number(this.parentPost.author_id || (this.parentPost.author as Dict)?.id || 0);
    if (authorId > 0 && blockRepo.isUserBlocked(authorId)) return true;
    return blockRepo.isContentBlocked('', this.buildSubContent(this.parentPost));
  }

  private extractSubPosts(data: Dict): Dict[] {
    if (!data) return [];
    const d = (data.data as Dict) || data;
    let list: Dict[] = [];
    if (Array.isArray(d.subpost_list)) list = d.subpost_list as Dict[];
    else if (Array.isArray(d.sub_post_list)) list = d.sub_post_list as Dict[];
    else if (Array.isArray(data.subpost_list)) list = data.subpost_list as Dict[];
    else if (Array.isArray(data.sub_post_list)) list = data.sub_post_list as Dict[];
    else if (Array.isArray(data.floor_list)) list = data.floor_list as Dict[];
    const blockRepo = BlockRepository.getInstance();
    return list.filter((sub: Dict) => {
      const authorId = Number(sub.author_id || (sub.author as Dict)?.id || 0);
      if (authorId > 0 && blockRepo.isUserBlocked(authorId)) return false;
      return !blockRepo.isContentBlocked('', this.buildSubContent(sub));
    });
  }

  private async loadMore(): Promise<void> {
    if (this.loadingMore) return;
    this.loadingMore = true;
    const nextPage = this.page + 1;
    try {
      const data: Dict = await this.repo.loadFloorPage(this.threadId, this.postId, this.forumId, nextPage);
      const more: Dict[] = this.extractSubPosts(data);
      if (more.length === 0) { this.hasMore = false; return; }
      this.subPosts = [...this.subPosts, ...more];
      this.page = nextPage;
      this.hasMore = this.checkHasMore(data);
      const rawUserList = data.user_list || (data.data as Dict)?.user_list || [];
      if (Array.isArray(rawUserList)) {
        for (const u of rawUserList as Dict[]) {
          if (u) { const uid = Number(u.id || u.user_id); if (uid > 0 && !this._userMap.has(uid)) this._userMap.set(uid, u); }
        }
      }
    } catch (e) {
      this.hasMore = false;
    } finally {
      this.loadingMore = false;
    }
  }

  private checkHasMore(data: Dict): boolean {
    if (!data) return false;
    const page = (data.page as Dict) || (data.data as Dict)?.page as Dict || {};
    const totalPage = Number(page.totalPage || page.total_page || 0);
    if (totalPage > 0) return this.page < totalPage;
    const raw = (data.data as Dict) || data;
    const hasMore = raw.has_more ?? data.has_more ?? page.has_more ?? 1;
    return Number(hasMore) !== 0;
  }

  onBackPress(): boolean {
    NavigationHelper.markBack();
    return false;
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
