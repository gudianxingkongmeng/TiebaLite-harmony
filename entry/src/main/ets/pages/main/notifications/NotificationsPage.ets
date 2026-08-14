import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import window from '@ohos.window';
import display from '@ohos.display';
import { NavigationHelper } from '../../../core/utils/NavigationHelper';
import { TiebaApi } from '../../../core/api/TiebaApi';
import HomeRepository from '../../../core/repository/HomeRepository';
import BlockRepository from '../../../core/repository/BlockRepository';
import AccountManager from '../../../core/auth/AccountManager';
import Avatar from '../../../components/Avatar';
import LoadingState from '../../../components/LoadingState';
import ErrorState from '../../../components/ErrorState';
import GearLoading from '../../../components/GearLoading';
import GearCycle from '../../../components/GearCycle';
import PullToRefresh from '../../../components/PullToRefresh';
import { Dict } from '../../../core/types/Dict';
import ITiebaApi, { ApiCallback } from '../../../core/api/ITiebaApi';
import { buildPortraitUrl, getStr, getNum, getStrObj, blendWithWhite, blendWithBg, textAccent, pageBg, cardBg, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor, withAlpha } from '../../../core/utils/DataHelper';

const TAB_NAMES: string[] = ['回复', '@ 我', '赞'];

@Component
export default struct NotificationsPage {
  @StorageLink('primaryColor') @Watch('onColorChanged') primaryColor: string = '#4477E0';
  @StorageLink('showSwiperDots') showSwiperDots: boolean = true;
  reduceEffects: boolean = false;
  @StorageLink('fontScale') fontScale: number = 1.0;
  @StorageLink('isDarkTheme') @Watch('onColorChanged') isDark: boolean = false;
  @StorageLink('headerAlpha') headerAlpha: number = 25;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @State bgColor: string = pageBg(AppStorage.Get<boolean>('isDarkTheme') ?? false);
  @State topInset: number = 24;
  @State selectedTab: number = 0;
  @State tabProgress: number = 0;
  @State replies: Dict[] = [];
  @State mentions: Dict[] = [];
  @State agrees: Dict[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  @State msgData: Dict | null = null;
  @State replyPage: number = 1;
  @State hasMoreReply: boolean = true;
  @State mentionPage: number = 1;
  @State hasMoreMention: boolean = true;
  @State agreePage: number = 1;
  @State hasMoreAgree: boolean = true;
  @State loadingMore: boolean = false;
  @State agreeLoadingMore: boolean = false;
  @State tabIndicatorOffset: number = 0;
  @State indicatorWidth: number = 20;
  @State tabTextWidths: number[] = [];
  @State tabBarWidth: number = 0;
  @State @Watch('onReplyRefreshChange') replyRefreshing: boolean = false;
  @State @Watch('onMentionRefreshChange') mentionRefreshing: boolean = false;
  @State @Watch('onAgreeRefreshChange') agreeRefreshing: boolean = false;
  @State pullDistance: number = 0;
  @State pullRefreshing: boolean = false;

  private tabNames: string[] = TAB_NAMES;
  private api: ITiebaApi = TiebaApi.getInstance();
  private loadLock: boolean = false;
  private scrollers: Scroller[] = [new Scroller(), new Scroller(), new Scroller()];
  @Prop @Watch('onActiveChanged') active: boolean = true;

  onActiveChanged(): void {
    this.reduceEffects = AppStorage.get<boolean>('reduceEffects') === true;
  }

  onColorChanged(): void {
    this.bgColor = pageBg(this.isDark);
  }

  private initTopInset(): void {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      window.getLastWindow(ctx).then((win: window.Window) => {
        const avoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        if (avoidArea.topRect.height > 0) {
          const density = display.getDefaultDisplaySync().densityPixels;
          this.topInset = Math.max(20, Math.round(avoidArea.topRect.height / density));
        }
      }).catch(() => { });
    } catch (e) {
      console.warn('TiebaLite: NotificationsPage initTopInset failed ' + JSON.stringify(e));
    }
  }

  aboutToAppear(): void {
    const t0 = new Date().getTime();
    console.info('TiebaLite: [N1] NotificationsPage aboutToAppear start t=' + t0);
    this.initTopInset();
    BlockRepository.getInstance().ensureLoaded().catch(() => {});
    if (!AccountManager.getInstance().isLoggedIn()) {
      console.info('TiebaLite: [N2] not logged in, skip t=' + (new Date().getTime() - t0) + 'ms');
      this.loading = false;
      this.error = '';
      return;
    }
    this.loadMsgCounts();
    const initialDone = AppStorage.Get<boolean>('notifInitialLoadDone') ?? false;
    if (!initialDone) {
      this.loadCurrentTab();
      AppStorage.SetOrCreate('notifInitialLoadDone', true);
    }
    AccountManager.getInstance().onAccountChange((): void => {
      this.replyPage = 1;
      this.mentionPage = 1;
      this.agreePage = 1;
      void this.loadCurrentTab();
    });
    setTimeout(() => { this.updateIndicatorOffset(); }, 0);
    console.info('TiebaLite: [N3] NotificationsPage aboutToAppear end t=' + (new Date().getTime() - t0) + 'ms');
  }

  onReplyRefreshChange(): void {
    if (this.replyRefreshing) {
      this.pullRefreshing = true;
      void this.refreshTab(0);
    } else {
      this.pullRefreshing = false;
      this.pullDistance = 0;
    }
  }
  onMentionRefreshChange(): void {
    if (this.mentionRefreshing) {
      this.pullRefreshing = true;
      void this.refreshTab(1);
    } else {
      this.pullRefreshing = false;
      this.pullDistance = 0;
    }
  }
  onAgreeRefreshChange(): void {
    if (this.agreeRefreshing) {
      this.pullRefreshing = true;
      void this.refreshTab(2);
    } else {
      this.pullRefreshing = false;
      this.pullDistance = 0;
    }
  }

  async refreshTab(tab: number): Promise<void> {
    this.error = '';
    try {
      if (tab === 0) {
        this.replyPage = 1;
        this.hasMoreReply = true;
        await this.loadReplyPage(1, true);
      } else if (tab === 1) {
        this.mentionPage = 1;
        this.hasMoreMention = true;
        await this.loadMentionPage(1, true);
      } else if (tab === 2) {
        this.agreePage = 1;
        this.hasMoreAgree = true;
        await this.loadAgreePage(1, true);
      }
    } catch (e) {
      this.error = '刷新失败';
    } finally {
      if (tab === 0) this.replyRefreshing = false;
      else if (tab === 1) this.mentionRefreshing = false;
      else if (tab === 2) this.agreeRefreshing = false;
    }
  }

  async loadMsgCounts(): Promise<void> {
    try {
      const data: Dict = await HomeRepository.getInstance().fetchMessageCount();
      this.msgData = data;
    } catch (e) {}
  }

  async loadCurrentTab(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      if (this.selectedTab === 0) {
        this.replyPage = 1;
        await this.loadReplyPage(1, true);
      } else if (this.selectedTab === 1) {
        this.mentionPage = 1;
        await this.loadMentionPage(1, true);
      } else if (this.selectedTab === 2) {
        this.agreePage = 1;
        await this.loadAgreePage(1, true);
      }
    } catch (e) {
      this.error = '加载失败';
      console.error('TiebaLite: notification error=' + String(e));
    } finally {
      this.loading = false;
    }
  }

  async loadReplyPage(page: number, replace: boolean): Promise<void> {
    const data: Dict = await this.promisify((cb: ApiCallback<Dict>): void => { this.api.replyMe(page, cb); });
    const d = (data.data as Dict) || data;
    const items = this.extractList(data);
    console.info('TiebaLite: replyMe p' + page + ' count=' + items.length + ' keys=' + (items[0] ? Object.keys(items[0]).join(',') : 'empty'));
    if (replace) {
      this.replies = items;
    } else if (items.length > 0) {
      const merged = this.dedupArray(this.replies, items);
      if (merged.length > this.replies.length) {
        this.replies = merged;
      } else {
        this.hasMoreReply = false;
        return;
      }
    }
    if (items.length === 0) {
      this.hasMoreReply = false;
    } else {
      const hasMoreField = d['has_more'] ?? d['hasMore'];
      this.hasMoreReply = hasMoreField !== undefined ? Number(hasMoreField) !== 0 : true;
    }
  }

  async loadMentionPage(page: number, replace: boolean): Promise<void> {
    const data: Dict = await this.promisify((cb: ApiCallback<Dict>): void => { this.api.atMe(page, cb); });
    const d = (data.data as Dict) || data;
    const items = this.extractList(data);
    console.info('TiebaLite: atMe p' + page + ' count=' + items.length);
    if (replace) {
      this.mentions = items;
    } else if (items.length > 0) {
      const merged = this.dedupArray(this.mentions, items);
      if (merged.length > this.mentions.length) {
        this.mentions = merged;
      } else {
        this.hasMoreMention = false;
        return;
      }
    }
    if (items.length === 0) {
      this.hasMoreMention = false;
    } else {
      const hasMoreField = d['has_more'] ?? d['hasMore'];
      this.hasMoreMention = hasMoreField !== undefined ? Number(hasMoreField) !== 0 : true;
    }
  }

  async loadAgreePage(page: number, replace: boolean): Promise<void> {
    const data: Dict = await this.promisify((cb: ApiCallback<Dict>): void => { this.api.agreeMe(page, cb); });
    const d = (data.data as Dict) || data;
    const items = this.extractList(data);
    console.info('TiebaLite: agreeMe p' + page + ' count=' + items.length + ' keys=' + (items[0] ? Object.keys(items[0]).join(',') : 'empty') + ' firstItem=' + JSON.stringify(items[0] || {}).substring(0, 500));
    console.info('TiebaLite: agreeMe respKeys=' + Object.keys(data).join(',') + ' dataKeys=' + Object.keys(d).join(',') + ' has_more=' + JSON.stringify(d['has_more']) + ' itemsFirstId=' + (items[0] ? items[0]['id'] : 'none'));
    if (items.length > 0 && items[0]) {
      const replyerEmpty = Object.keys(this.getReplyer(items[0])).length === 0;
      const contentEmpty = !this.getContent(items[0]);
      const aiObj = items[0].agree_info as Dict;
      const aObj = items[0].agree as Dict;
      const aiKeys = aiObj ? Object.keys(aiObj).join(',') : '';
      const aKeys = aObj ? Object.keys(aObj).join(',') : '';
      console.info('TiebaLite: agreeMe emptyFields replyer=' + replyerEmpty + ' content=' + contentEmpty + ' itemKeys=' + Object.keys(items[0]).join(',') + ' agreeInfoKeys=' + aiKeys + ' agreeKeys=' + aKeys);
      const fullDump: string = JSON.stringify(items[0]).substring(0, 2000);
      console.info('TiebaLite: agreeMe FULL first item: ' + fullDump);
    }
    if (replace) {
      this.agrees = items;
    } else if (items.length > 0) {
      const merged = this.dedupArray(this.agrees, items);
      if (merged.length > this.agrees.length) {
        this.agrees = merged;
      } else {
        this.hasMoreAgree = false;
        return;
      }
    }
    if (items.length === 0) {
      this.hasMoreAgree = false;
    } else {
      const hasMoreField = d['has_more'] ?? d['hasMore'];
      this.hasMoreAgree = hasMoreField !== undefined ? Number(hasMoreField) !== 0 : true;
    }
  }

  private getWinWidth(): number {
    return 360;
  }

  private updateIndicatorOffset(): void {
    const totalTabs = this.tabNames.length;
    const contentWidth = this.tabBarWidth > 0 ? this.tabBarWidth : (this.getWinWidth() - 32);
    const tabWidth = contentWidth / totalTabs;

    const clamped = Math.max(0, Math.min(this.tabProgress, totalTabs - 1));
    const fraction = clamped - Math.floor(clamped);
    const factor = 1 - Math.abs(fraction - 0.5) * 2;
    const staticWidth = this.tabTextWidths[Math.round(clamped)] || 20;
    this.indicatorWidth = staticWidth + staticWidth * 2 * factor;

    this.tabIndicatorOffset = 16 + tabWidth * clamped + tabWidth / 2 - this.indicatorWidth / 2;
  }

  switchTab(index: number): void {
    if (this.selectedTab === index) return;
    animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
      this.selectedTab = index;
      this.tabProgress = index;
      this.updateIndicatorOffset();
    });
    const needLoad = (index === 0 && this.replies.length === 0) ||
      (index === 1 && this.mentions.length === 0) ||
      (index === 2 && this.agrees.length === 0);
    if (needLoad) { this.loadCurrentTab(); }
  }

  onSwiperChange(index: number): void {
    if (this.selectedTab === index) return;
    this.selectedTab = index;
    const needLoad = (index === 0 && this.replies.length === 0) ||
      (index === 1 && this.mentions.length === 0) ||
      (index === 2 && this.agrees.length === 0);
    if (needLoad) { this.loadCurrentTab(); }
  }

  async loadNextPage(): Promise<void> {
    if (this.loadLock) return;
    this.loadLock = true;
    try {
      const shouldLoad = (this.selectedTab === 0 && this.hasMoreReply) ||
                         (this.selectedTab === 1 && this.hasMoreMention) ||
                         (this.selectedTab === 2 && this.hasMoreAgree);
      if (!shouldLoad) return;
      if (this.selectedTab === 2) {
        if (this.agreeLoadingMore) return;
        this.agreeLoadingMore = true;
      } else {
        if (this.loadingMore) return;
        this.loadingMore = true;
      }
      if (this.selectedTab === 0) {
        this.replyPage++;
        await this.loadReplyPage(this.replyPage, false);
      } else if (this.selectedTab === 1) {
        this.mentionPage++;
        await this.loadMentionPage(this.mentionPage, false);
      } else if (this.selectedTab === 2) {
        this.agreePage++;
        await this.loadAgreePage(this.agreePage, false);
      }
    } catch (e) {} finally {
      this.loadLock = false;
      if (this.selectedTab === 2) {
        this.agreeLoadingMore = false;
      } else {
        this.loadingMore = false;
      }
    }
  }

  private promisify(fn: (cb: ApiCallback<Dict>) => void): Promise<Dict> {
    return new Promise((resolve, reject) => {
      fn({
        onSuccess: (data: Dict) => resolve(data),
        onError: (code: number, msg: string) => reject({ code, msg })
      });
    });
  }

  private extractList(data: Dict): Dict[] {
    if (!data) return [];
    const d = (data.data as Dict) || data;
    const keys = ['reply_list', 'at_list', 'agree_list', 'list', 'msg_list', 'feed_list'];
    let result: Dict[] = [];
    for (const key of keys) {
      if (d[key] && Array.isArray(d[key]) && (d[key] as Dict[]).length > 0) {
        result = d[key] as Dict[];
        break;
      }
    }
    if (result.length === 0) {
      if (Array.isArray(data)) result = data as Dict[];
      else if (Array.isArray(d)) result = d as Dict[];
    }
    if (result.length === 0) {
      console.info('TiebaLite: extractList no match, first-level keys=' + Object.keys(data).join(',') + ' data-keys=' + Object.keys(d).join(','));
      return [];
    }
    const blockRepo = BlockRepository.getInstance();
    return result.filter((item: Dict) => {
      const replyer = this.getReplyer(item);
      const uid = Number(getStr(replyer, 'id', 'user_id', 'uid', 'userId', 'agree_uid', 'agreeUid') || 0);
      if (uid > 0 && blockRepo.isUserBlocked(uid)) return false;
      const content = this.getContent(item);
      return !blockRepo.isContentBlocked('', content);
    });
  }

  private dedupArray(existing: Dict[], incoming: Dict[]): Dict[] {
    const keySet = new Set<string>();
    for (const e of existing) keySet.add(this.getItemId(e));
    const unique = incoming.filter((i) => {
      const key = this.getItemId(i);
      if (keySet.has(key)) return false;
      keySet.add(key);
      return true;
    });
    return [...existing, ...unique];
  }

  private getItemId(item: Dict): string {
    const id = getStr(item, 'id', 'thread_id', 'threadId', 'post_id', 'postId', 'tid', 'pid', 'agree_id', 'agreeId', 'agreeId');
    if (id) return 'id:' + id;
    const subObjs: string[] = ['post_info', 'thread_info', 'source', 'thread', 'agree', 'agree_info', 'agree_info_ext', 'post', 'reply'];
    for (const sub of subObjs) {
      const obj = item[sub] as Dict;
      if (obj) {
        const sid = getStr(obj, 'id', 'thread_id', 'threadId', 'post_id', 'postId', 'tid', 'pid');
        if (sid) return 'id:' + sid;
      }
    }
    const author = this.getReplyer(item);
    const authorName = getStr(author, 'name', 'name_show', 'user_name', 'nickname');
    const content = this.getContent(item).substring(0, 50);
    const time = this.getTime(item);
    return authorName + '|' + content + '|' + time;
  }

  private getUnreadCount(tabIndex: number): number {
    if (!this.msgData) return 0;
    const innerData = this.msgData.data as Dict;
    const msg: Dict = (innerData && innerData.message) ? (innerData.message as Dict) : ((this.msgData.message as Dict) || {});
    if (tabIndex === 0) return getNum(msg, 'reply', 'replyme');
    if (tabIndex === 1) return getNum(msg, 'at', 'atme');
    if (tabIndex === 2) return getNum(msg, 'agree', 'agreeme');
    return 0;
  }

  private getReplyer(item: Dict): Dict {
    const checks: string[] = ['agreeer', 'replyer', 'author', 'user', 'replyer_info', 'author_info', 'agree_user', 'agreeUser', 'agree_replyer', 'agreeReplyer', 'agreeUserInfo', 'agree_user_info', 'likeUser', 'like_user', 'fromUser', 'from_user', 'fromUserInfo', 'from_user_info', 'user_info'];
    for (const key of checks) {
      const v = item[key];
      if (v && typeof v === 'object' && !Array.isArray(v)) return v as Dict;
    }
    const subObjs: string[] = ['post_info', 'thread_info', 'source', 'thread', 'agree', 'agree_info', 'agree_info_ext', 'agree_ext', 'post', 'reply'];
    for (const sub of subObjs) {
      const obj = item[sub] as Dict;
      if (obj) {
        for (const key of checks) {
          const v = obj[key];
          if (v && typeof v === 'object' && !Array.isArray(v)) return v as Dict;
        }
      }
    }
    // deep nested scan: traverse sub-objects for user-like objects
    const deepPaths: string[][] = [
      ['agree_info', 'agree_user'], ['agree', 'agree_user'],
      ['agree_info', 'user'], ['agree', 'user'],
      ['agree_info', 'replyer'], ['agree', 'replyer'],
      ['agree_info', 'author'], ['agree', 'author'],
      ['agree_info_ext', 'agree_user'], ['agree_info_ext', 'user'],
      ['agree_info', 'agree_info'], ['agree_info', 'agree'],
      ['source', 'agree_info', 'agree_user'], ['source', 'agree', 'agree_user'],
      ['agree_info', 'post', 'author'], ['agree_info', 'thread', 'author'],
      ['post_info', 'author'], ['thread_info', 'author'],
    ];
    for (const path of deepPaths) {
      let obj: Dict | undefined = item;
      for (const key of path) {
        if (!obj) break;
        obj = obj[key] as Dict;
      }
      if (obj && typeof obj === 'object' && !Array.isArray(obj)) {
        if (getStr(obj, 'id', 'user_id', 'uid', 'userId', 'name', 'name_show', 'user_name', 'nickname', 'portrait', 'avatar')) {
          return obj;
        }
      }
    }
    // fallback: construct from flat user fields
    const flatSrcs: Dict[] = [item, item.agreeer as Dict || {}, item.post_info as Dict || {}, item.agree_info as Dict || {}, item.agree as Dict || {}, item.agree_info_ext as Dict || {}];
    for (const src of flatSrcs) {
      if (!src) continue;
      const uid = getStr(src, 'user_id', 'userId', 'uid', 'agree_uid', 'agreeUid', 'id');
      const uname = getStr(src, 'user_name', 'userName', 'username', 'agree_user_name', 'agreeUserName', 'name', 'name_show');
      const upic = getStr(src, 'user_portrait', 'userPortrait', 'portrait', 'agree_user_portrait', 'agreeUserPortrait', 'avatar');
      if (uid || uname) {
        return { 'name': uname || '', 'name_show': uname || '', 'id': uid || '', 'portrait': upic || '' } as Dict;
      }
    }
    // final fallback: scan every direct child for a user-like object
    for (const k of Object.keys(item)) {
      const v = item[k];
      if (v && typeof v === 'object' && !Array.isArray(v)) {
        const obj = v as Dict;
        if (getStr(obj, 'id', 'user_id', 'uid', 'userId') || getStr(obj, 'name', 'name_show', 'user_name', 'nickname') || getStr(obj, 'portrait', 'avatar', 'user_portrait', 'portrait_url', 'icon')) {
          return obj;
        }
      }
    }
    return {};
  }

  private getContent(item: Dict): string {
    const direct = getStr(item, 'content', 'text', 'message', 'reply_text', 'agree_content', 'agreeContent', 'post_content', 'postContent', 'first_post_content', 'abstract', 'excerpt', 'title', 'agree_text', 'agreeText');
    if (direct) return direct;
    const subObjs: string[] = ['post_info', 'thread_info', 'source', 'thread', 'agree', 'agree_info', 'agree_info_ext', 'agree_ext', 'post', 'reply'];
    for (const sub of subObjs) {
      const obj = item[sub] as Dict;
      if (obj) {
        const found = getStr(obj, 'content', 'text', 'message', 'reply_text', 'agree_content', 'agreeContent', 'agree_text', 'agreeText', 'post_content', 'postContent', 'first_post_content', 'abstract', 'excerpt', 'title');
        if (found) return found;
        const arr = obj['content'] as Dict[];
        if (Array.isArray(arr)) {
          let text = '';
          for (const c of arr) { if (c.text && c.type !== 2) text += String(c.text); }
          if (text) return text;
        }
        const arr2 = obj['agree_content'] as Dict[] || obj['agreeContent'] as Dict[] || obj['post_content'] as Dict[];
        if (Array.isArray(arr2)) {
          let text = '';
          for (const c of arr2) { if (c.text && c.type !== 2) text += String(c.text); }
          if (text) return text;
        }
      }
    }
    const nestedPaths: string[][] = [
      ['agree_info', 'post'], ['agree_info', 'thread'], ['agree_info', 'source'],
      ['source', 'thread'], ['source', 'post'], ['source', 'agree_info', 'post'],
      ['agree_info', 'agree_info', 'post'], ['agree', 'post'], ['agree', 'thread'],
      ['agree_info', 'agree_info'], ['agree_info', 'agree_info', 'agree_info'],
      ['agree_info', 'post', 'content'], ['agree_info', 'thread', 'content'],
      ['post_info'], ['post_info', 'content'], ['thread_info']
    ];
    for (const path of nestedPaths) {
      let obj: Dict | undefined = item;
      for (const key of path) {
        if (!obj) break;
        obj = obj[key] as Dict;
      }
      if (obj) {
        const found = getStr(obj, 'content', 'text', 'message', 'reply_text', 'agree_content', 'agreeContent', 'agree_text', 'agreeText', 'post_content', 'postContent', 'first_post_content', 'abstract', 'excerpt', 'title');
        if (found) return found;
        const arr = obj['content'] as Dict[];
        if (Array.isArray(arr)) {
          let text = '';
          for (const c of arr) { if (c.text && c.type !== 2) text += String(c.text); }
          if (text) return text;
        }
      }
    }
    const arrKeys = ['content', 'post_content', 'firstPostContent', 'first_post_content', 'agree_content', 'agreeContent'];
    for (const k of arrKeys) {
      const arr = item[k] as Dict[];
      if (Array.isArray(arr)) {
        let text = '';
        for (const c of arr) { if (c.text && c.type !== 2) text += String(c.text); }
        if (text) return text;
      }
    }
    const backstop = getStr(item, 'title', 'thread_title', 'post_title', 'topic_name', 'forum_name');
    if (backstop) return backstop;
    // fallback: scan every direct child for string content or text arrays
    for (const k of Object.keys(item)) {
      const v = item[k];
      if (typeof v === 'string' && v.length > 3 && !/^\d+$/.test(v) && !/^https?:\/\//.test(v)) {
        return v;
      }
      if (Array.isArray(v)) {
        let txt = '';
        for (const el of v as Dict[]) {
          if (typeof el === 'object' && el && el.text && el.type !== 2) txt += String(el.text);
        }
        if (txt) return txt;
      }
      if (v && typeof v === 'object' && !Array.isArray(v)) {
        const obj = v as Dict;
        const directText = getStr(obj, 'content', 'text', 'message', 'agree_text', 'agreeText', 'reply_text', 'post_content', 'postContent', 'first_post_content', 'abstract', 'excerpt');
        if (directText) return directText;
        for (const ak of Object.keys(obj)) {
          const av = obj[ak];
          if (typeof av === 'string' && av.length > 3 && !/^\d+$/.test(av) && !/^https?:\/\//.test(av)) {
            return av;
          }
        }
      }
    }
    if (!this._loggedEmptyKeys) {
      console.info('TiebaLite: getContent empty, item keys=' + Object.keys(item).join(',') + ' sample=' + JSON.stringify(item).substring(0, 800));
      this._loggedEmptyKeys = true;
    }
    return '';
  }
  private _loggedEmptyKeys: boolean = false;

  private getTitle(item: Dict): string {
    const direct = getStr(item, 'title', 'thread_title', 'post_title', 'topic_name', 'threadTitle', 'postTitle');
    if (direct) return direct;
    const subObjs: string[] = ['post_info', 'thread_info', 'source', 'thread', 'agree', 'agree_info', 'post', 'reply'];
    for (const sub of subObjs) {
      const obj = item[sub] as Dict;
      if (obj) {
        const found = getStr(obj, 'title', 'thread_title', 'post_title', 'topic_name', 'threadTitle', 'postTitle');
        if (found) return found;
      }
    }
    return '';
  }

  private getTime(item: Dict): string {
    const direct = getStr(item, 'time', 'timestamp', 'create_time', 'reply_time', 'last_time');
    if (direct) return direct;
    const subObjs: string[] = ['post_info', 'thread_info', 'source', 'thread', 'agree', 'agree_info', 'agree_info_ext', 'agree_ext', 'post', 'reply'];
    for (const sub of subObjs) {
      const obj = item[sub] as Dict;
      if (obj) {
        const found = getStr(obj, 'time', 'timestamp', 'create_time', 'reply_time', 'last_time', 'agree_time', 'agreeTime');
        if (found) return found;
      }
    }
    return '';
  }

  private getQuoteContent(item: Dict): string {
    const qc = getStr(item, 'quote_content', 'quote', 'quote_text', 'pre_content', 'quoteContent');
    if (qc && qc !== this.getContent(item)) return qc;
    const subObjs: string[] = ['post_info', 'thread_info', 'source', 'thread', 'agree', 'agree_info', 'agree_info_ext', 'post', 'reply'];
    for (const sub of subObjs) {
      const obj = item[sub] as Dict;
      if (obj) {
        const found = getStr(obj, 'quote_content', 'quote', 'quote_text', 'pre_content', 'quoteContent');
        if (found && found !== this.getContent(item)) return found;
      }
    }
    const nestedSubObjs: string[] = ['agree_info', 'agree_info_ext', 'source'];
    for (const sub of nestedSubObjs) {
      const obj = item[sub] as Dict;
      if (obj) {
        for (const inner of ['post', 'thread', 'source', 'reply']) {
          const innerObj = obj[inner] as Dict;
          if (innerObj) {
            const found = getStr(innerObj, 'quote_content', 'quote', 'quote_text', 'pre_content', 'quoteContent');
            if (found && found !== this.getContent(item)) return found;
          }
        }
      }
    }
    return '';
  }

  private getForumName(item: Dict): string {
    let fname = getStr(item, 'fname', 'forum_name', 'forumName');
    if (fname) return fname;
    const subObjs: string[] = ['post_info', 'thread_info', 'source', 'thread', 'agree', 'agree_info', 'agree_info_ext', 'post', 'reply'];
    for (const sub of subObjs) {
      const obj = item[sub] as Dict;
      if (obj) {
        fname = getStr(obj, 'fname', 'forum_name', 'forumName');
        if (fname) return fname;
      }
    }
    const nestedSubObjs: string[] = ['agree_info', 'agree_info_ext', 'source'];
    for (const sub of nestedSubObjs) {
      const obj = item[sub] as Dict;
      if (obj) {
        for (const inner of ['thread', 'source', 'post']) {
          const innerObj = obj[inner] as Dict;
          if (innerObj) {
            fname = getStr(innerObj, 'fname', 'forum_name', 'forumName');
            if (fname) return fname;
          }
        }
      }
    }
    return '';
  }

  private getThreadTitle(item: Dict): string {
    let title = getStr(item, 'title', 'thread_title', 'post_title', 'topic_name', 'threadTitle', 'postTitle');
    if (title) return title;
    const subObjs: string[] = ['post_info', 'thread_info', 'source', 'thread', 'agree', 'agree_info', 'agree_info_ext', 'post', 'reply'];
    for (const sub of subObjs) {
      const obj = item[sub] as Dict;
      if (obj) {
        title = getStr(obj, 'title', 'thread_title', 'post_title', 'topic_name', 'threadTitle', 'postTitle');
        if (title) return title;
      }
    }
    const nestedPaths: string[][] = [
      ['agree_info', 'thread'], ['agree_info', 'source', 'thread'],
      ['source', 'thread'], ['agree', 'thread'], ['agree_info', 'source'],
      ['agree_info', 'post', 'thread'], ['post', 'thread'],
      ['agree_info', 'agree_info', 'thread'],
      ['agree_info', 'agree_info', 'source', 'thread'],
      ['agree_info_ext', 'thread'],
      ['thread_info'], ['post_info'], ['post_info', 'thread_info']
    ];
    for (const path of nestedPaths) {
      let obj: Dict | undefined = item;
      for (const key of path) {
        if (!obj) break;
        obj = obj[key] as Dict;
      }
      if (obj) {
        title = getStr(obj, 'title', 'thread_title', 'post_title', 'topic_name', 'threadTitle', 'postTitle');
        if (title) return title;
      }
    }
    return '';
  }

  @Builder
  notifListContent(tab: number) {
    List({ scroller: this.scrollers[tab] }) {
      ListItem() { Column() { Blank().height(38) } }
      if (tab === 0) {
        if (this.replies.length === 0) {
          ListItem() { Text('暂无回复').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark)).width('100%').textAlign(TextAlign.Center).margin({ top: 80 }) }
        } else {
          ForEach(this.replies, (item: Dict, idx: number) => {
            ListItem() { this.NotificationItem(item) }
          }, (item: Dict): string => this.getItemId(item))
        }
      } else if (tab === 1) {
        if (this.mentions.length === 0) {
          ListItem() { Text('暂无@消息').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark)).width('100%').textAlign(TextAlign.Center).margin({ top: 80 }) }
        } else {
          ForEach(this.mentions, (item: Dict, idx: number) => {
            ListItem() { this.NotificationItem(item) }
          }, (item: Dict): string => this.getItemId(item))
        }
      } else {
        if (this.agrees.length === 0) {
          ListItem() { Text('暂无赞').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark)).width('100%').textAlign(TextAlign.Center).margin({ top: 80 }) }
        } else {
          ForEach(this.agrees, (item: Dict, idx: number) => {
            ListItem() { this.NotificationItem(item) }
          }, (item: Dict): string => this.getItemId(item))
          if (this.agreeLoadingMore) {
          } else if (this.hasMoreAgree) {
            ListItem() {
              Column() {
                Text('加载更多').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor('#4477E0').width('100%').textAlign(TextAlign.Center).padding(16).onClick(() => { void this.loadNextPage(); })
              }
            }
          } else {
            ListItem() {
              Column() {
                Text('没有更多了').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark)).width('100%').textAlign(TextAlign.Center).padding(16)
              }
            }
          }
        }
      }
      ListItem() { Column() { Blank().height(66) } }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor(this.bgColor)
    .edgeEffect(EdgeEffect.None)
    .onReachEnd(() => { void this.loadNextPage(); })
  }

  build() {
    Stack() {
      Column()
        .width('100%').height('100%')
.backgroundColor(this.bgColor)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      Column() {
        Stack() {
          Row() {
            ForEach(this.tabNames, (name: string, index: number) => {
            Column() {
              Row() {
              Text(name).fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale))
                  .fontColor(this.selectedTab === index ? textAccent(this.primaryColor, this.isDark) : textSecondary(this.isDark))
                  .fontWeight(this.selectedTab === index ? FontWeight.Bold : FontWeight.Regular)
                  .onAreaChange((_old: Area, newArea: Area): void => {
                    const w = newArea.width as number;
                    if (w > 0 && Math.abs(w - (this.tabTextWidths[index] || 0)) > 0.5) {
                      this.tabTextWidths[index] = w;
                    }
                  })
                if (this.getUnreadCount(index) > 0) {
                  Text(this.getUnreadCount(index) > 99 ? '99+' : String(this.getUnreadCount(index)))
                    .fontFamily(this.appFontFamily).fontSize(10).fontColor('#FFFFFF').backgroundColor('#FF4444').borderRadius(8)
                    .padding({ left: 5, right: 5, top: 2, bottom: 2 }).margin({ left: 4 })
                }
              }.padding({ bottom: 8 })
            }
            .layoutWeight(1).padding({ top: 12 })
            .onClick(() => { this.switchTab(index); })
          })
        }
        .width('100%').padding({ left: 16, right: 16 })


        Column()
          .width(this.indicatorWidth).height(3).backgroundColor(this.primaryColor).borderRadius(2)
          .position({ left: this.tabIndicatorOffset, bottom: 0 })
      }
      .width('100%')
      .backgroundColor(withAlpha(this.bgColor, 1 - this.headerAlpha / 100))
      .backdropBlur(60)
      .border({ width: { bottom: 1 }, color: blendWithBg(this.primaryColor, 0.15, this.isDark, '#1E1E1E') })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
      .position({ x: 0, y: 0 })
      .zIndex(2)
      .onAreaChange((_old: Area, newArea: Area) => {
        const w = newArea.width as number;
        if (w > 0 && Math.abs(w - this.tabBarWidth) > 0.5) {
          this.tabBarWidth = w - 32;
          this.updateIndicatorOffset();
        }
      })

      if (this.loading) {
        LoadingState({ message: '加载中...' })
      } else if (!AccountManager.getInstance().isLoggedIn()) {
        Column() {
          Text('请先登录').fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontColor(textTertiary(this.isDark)).width('100%').textAlign(TextAlign.Center).margin({ top: 80 })
          Button('去登录').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor('#FFFFFF').backgroundColor(this.primaryColor).borderRadius(22).height(40).width(120).margin({ top: 16 })
            .onClick(() => { NavigationHelper.navigate('pages/login/LoginPage'); })
        }
        .width('100%').layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.error.length > 0) {
        ErrorState({ message: this.error, onRetryAction: (): void => { void this.loadCurrentTab(); } })
} else {
        Swiper() {
          if (this.reduceEffects) {
            PullToRefresh({
              reduceEffects: true,
              scroller: this.scrollers[0],
              iconTopOffset: 40,
              isRefreshing: this.replyRefreshing,
              onRefresh: (): void => { this.replyRefreshing = true; },
              onTimeout: (): void => { this.replyRefreshing = false; }
            }) {
              this.notifListContent(0)
            }
          } else {
            PullToRefresh({
              scroller: this.scrollers[0],
              iconTopOffset: 40,
              isRefreshing: this.replyRefreshing,
              onRefresh: (): void => { this.replyRefreshing = true; },
              onTimeout: (): void => { this.replyRefreshing = false; }
            }) {
              this.notifListContent(0)
            }
          }

          if (this.reduceEffects) {
            PullToRefresh({
              reduceEffects: true,
              scroller: this.scrollers[1],
              iconTopOffset: 40,
              isRefreshing: this.mentionRefreshing,
              onRefresh: (): void => { this.mentionRefreshing = true; },
              onTimeout: (): void => { this.mentionRefreshing = false; }
            }) {
              this.notifListContent(1)
            }
          } else {
            PullToRefresh({
              scroller: this.scrollers[1],
              iconTopOffset: 40,
              isRefreshing: this.mentionRefreshing,
              onRefresh: (): void => { this.mentionRefreshing = true; },
              onTimeout: (): void => { this.mentionRefreshing = false; }
            }) {
              this.notifListContent(1)
            }
          }

          if (this.reduceEffects) {
            PullToRefresh({
              reduceEffects: true,
              scroller: this.scrollers[2],
              iconTopOffset: 40,
              isRefreshing: this.agreeRefreshing,
              onRefresh: (): void => { this.agreeRefreshing = true; },
              onTimeout: (): void => { this.agreeRefreshing = false; }
            }) {
              this.notifListContent(2)
            }
          } else {
            PullToRefresh({
              scroller: this.scrollers[2],
              iconTopOffset: 40,
              isRefreshing: this.agreeRefreshing,
              onRefresh: (): void => { this.agreeRefreshing = true; },
              onTimeout: (): void => { this.agreeRefreshing = false; }
            }) {
              this.notifListContent(2)
            }
          }

        }
        .layoutWeight(1).width('100%').clip(false)
        .loop(false).index(this.selectedTab)
        .disableSwipe(false)
        .indicator(this.showSwiperDots)
        .onChange((idx: number) => { this.onSwiperChange(idx); })
        .onAnimationStart((_index: number, targetIndex: number, _extraInfo: SwiperAnimationEvent) => {
          animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
            this.tabProgress = targetIndex;
            this.updateIndicatorOffset();
          });
        })
      }
    }
      .width('100%').height('100%').justifyContent(FlexAlign.Start).backgroundColor(this.bgColor).expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      if (((this.selectedTab !== 2 && this.loadingMore) || (this.selectedTab === 2 && this.agreeLoadingMore))) {
        Column() {
          GearCycle({ gearSize: 32, color: this.primaryColor, refreshing: true })
        }
        .width('100%')
        .position({ bottom: 90, left: 0, right: 0 })
        .zIndex(10)
      }
    }
    .width('100%').height('100%').backgroundColor(this.bgColor)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    
  }

  @Builder
  NotificationItem(item: Dict) {
    Column() {
      Row() {
      Avatar({
          portrait: buildPortraitUrl(getStr(this.getReplyer(item), 'portrait', 'portrait_url', 'icon', 'avatar')),
          avatarSize: 40,
          defaultName: getStr(this.getReplyer(item), 'name', 'name_show', 'user_name', 'nickname')
        })
        Column() {
          Text(getStr(this.getReplyer(item), 'name', 'name_show', 'user_name', 'nickname'))
            .fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontColor(textPrimary(this.isDark)).fontWeight(FontWeight.Medium)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.formatTime(this.getTime(item)))
            .fontFamily(this.appFontFamily).fontSize(Math.round(11 * this.fontScale)).fontColor(textTertiary(this.isDark)).margin({ top: 2 })

          Text(this.getContent(item))
            .fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontColor(textPrimary(this.isDark)).maxLines(5)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 8 })
            .lineHeight(Math.round(22 * this.fontScale))

          if (this.getThreadTitle(item) || this.getQuoteContent(item)) {
            Column() {
              if (this.getThreadTitle(item)) {
                Text(this.getThreadTitle(item))
                  .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(textAccent(this.primaryColor, this.isDark)).fontWeight(FontWeight.Medium).maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
              }
              if (this.getQuoteContent(item)) {
                Text(this.getQuoteContent(item))
                  .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textSecondary(this.isDark)).maxLines(4)
                  .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%').lineHeight(Math.round(20 * this.fontScale))
                  .margin({ top: this.getThreadTitle(item) ? 4 : 0 })
              }
            }
            .width('100%').padding(10)
            .backgroundColor(blendWithBg(this.primaryColor, 0.12, this.isDark, '#1E1E1E'))
            .borderRadius(8).margin({ top: 8 })
          }
        }
        .layoutWeight(1).margin({ left: 12 }).alignItems(HorizontalAlign.Start)
      }
      .width('100%').alignItems(VerticalAlign.Top)
    }
    .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .onClick(() => {
      let threadId = getStr(item, 'thread_id', 'threadId', 'tid');
      const postId = getStr(item, 'post_id', 'postId', 'pid');
      if (!threadId || threadId === '0') {
        const source = item.source as Dict;
        if (source) threadId = getStr(source, 'thread_id', 'threadId', 'tid');
      }
      if (!threadId || threadId === '0') {
        const thread = item.thread as Dict;
        if (thread) threadId = getStr(thread, 'id', 'thread_id', 'threadId', 'tid');
      }
      if (!threadId || threadId === '0') {
        const ti = item.thread_info as Dict;
        if (ti) threadId = getStr(ti, 'id', 'thread_id', 'threadId', 'tid');
      }
      if ((!threadId || threadId === '0') && item.agree_info) {
        const ai = item.agree_info as Dict;
        threadId = getStr(ai, 'thread_id', 'threadId', 'tid');
      }
      if ((!threadId || threadId === '0') && item.agree_info_ext) {
        const ai = item.agree_info_ext as Dict;
        threadId = getStr(ai, 'thread_id', 'threadId', 'tid');
      }
      if (threadId && threadId !== '0') {
        NavigationHelper.navigate('pages/thread/ThreadPage', {
          threadId: threadId,
          postId: postId,
          forumName: this.getForumName(item)
        });
      }
    })
  }

  private formatTime(timeStr: string): string {
    if (!timeStr) return '';
    const ts = Number(timeStr);
    if (isNaN(ts)) return timeStr;
    if (ts < 1e8) return '';
    const d = new Date(ts > 1e12 ? ts : ts * 1000);
    const diff = Date.now() - d.getTime();
    if (diff < 60000) return '刚刚';
    if (diff < 3600000) return Math.floor(diff / 60000) + '分钟前';
    if (diff < 86400000) return Math.floor(diff / 3600000) + '小时前';
    if (diff < 172800000) return '昨天';
    if (diff < 2592000000) return Math.floor(diff / 86400000) + '天前';
    const month = (d.getMonth() + 1).toString().padStart(2, '0');
    const day = d.getDate().toString().padStart(2, '0');
    return month + '-' + day + ' ' + d.getHours().toString().padStart(2, '0') + ':' + d.getMinutes().toString().padStart(2, '0');
  }
}

