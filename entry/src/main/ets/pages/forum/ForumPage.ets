import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import window from '@ohos.window';
import display from '@ohos.display';
import promptAction from '@ohos.promptAction';
import ForumRepository from '../../core/repository/ForumRepository';
import PreferencesManager from '../../core/storage/PreferencesManager';
import PbPageRepository from '../../core/repository/PbPageRepository';
import BlockRepository from '../../core/repository/BlockRepository';
import AccountManager from '../../core/auth/AccountManager';
import ThreadCard from '../../components/ThreadCard';
import LoadingState from '../../components/LoadingState';
import ErrorState from '../../components/ErrorState';
import Avatar from '../../components/Avatar';
import GearLoading from '../../components/GearLoading';
import PullToRefresh from '../../components/PullToRefresh';
import { Dict } from '../../core/types/Dict';
import { getStr, getNum, blendWithWhite, darkenColor, blendWithBg, textAccent, pageBg, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor, withAlpha, buildPortraitUrl, primaryContainer, onPrimaryContainer } from '../../core/utils/DataHelper';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import { GripDetector } from '../../core/utils/GripDetector';

interface ForumTab {
  tabId: number;
  tabName: string;
  tabType: number;
  isGeneralTab: number;
}

@Entry
@Component
struct ForumPage {
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  @StorageLink('showSwiperDots') showSwiperDots: boolean = true;
  @StorageLink('gripSide') @Watch('onGripSideChanged') gripSide: number = 0;
  @StorageLink('fabRadius') fabRadius: number = 60;
  reduceEffects: boolean = false;
  @StorageLink('fontScale') fontScale: number = 1.0;
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('cardStyle') cardStyle: number = 0;
  @StorageLink('headerAlpha') headerAlpha: number = 25;
  @StorageLink('headerTint') headerTint: number = 8;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @StorageProp('hideOnScroll') hideOnScroll: boolean = true;
  @State forumName: string = '';
  @State forumAvatar: string = '';
  @State forumId: number = 0;
  @State topInset: number = 24;
  @State threads: Dict[] = [];
  @State topThreads: Dict[] = [];
  @State forumRule: Dict | null = null;
  @State ruleTitle: string = '';
  @State page: number = 1;
  @State sortType: number = 6;
  @State showSortDropdown: boolean = false;
  private sortNames: string[] = ['按回复时间', '按发布时间'];
  @State loading: boolean = true;
  @State error: string = '';
  @State hasMore: boolean = true;
  @State loadingMore: boolean = false;
  @State isLiked: boolean = false;
  @State signedToday: boolean = false;
  @State topExpanded: boolean = false;
  @State rightHotThreads: Dict[] = [];
  @State rightHotPage: number = 1;
  @State rightHotHasMore: boolean = true;
  @State goodThreads: Dict[] = [];
  @State goodPage: number = 1;
  @State goodHasMore: boolean = true;
  @State goodError: string = '';
  @State fabVisible: boolean = false;
  @State fabLeft: boolean = false;
  @State showFabMenu: boolean = false;
  private fabTimer: number = -1;
  private lastFabScrollY: number = -1;
  @State headerCollapsed: boolean = false;
  private lastHeaderY: number = 0;
  private lastHeaderScroller: Scroller | null = null;
  private readonly nameRowHeight: number = 50;
  @State selectedTab: number = 0;
  @State tabProgress: number = 0;
  @State tabIndicatorOffset: number = 0;
  @State indicatorWidth: number = 20;
  @State tabBarWidth: number = 0;
  @State tabItemWidths: number[] = [];
  @State goodLoading: boolean = false;
  @State hotLoading: boolean = false;
  @State consecutiveSignDays: number = 0;
  @State forumTabs: ForumTab[] = [];
  @State catThreads: Dict[][] = [];
  @State catPage: number[] = [];
  @State catHasMore: boolean[] = [];
  @State catLoading: boolean[] = [];
  @State catError: string[] = [];
  @State catLastId: number[] = [];
  private catScrollers: Scroller[] = [];

  @State @Watch('onRefreshStateChange0') isRefreshing0: boolean = false;
  @State @Watch('onRefreshStateChange1') isRefreshing1: boolean = false;
  @State @Watch('onRefreshStateChangeGood') isRefreshingGood: boolean = false;
  @State pullDistance: number = 0;
  @State pullRefreshing: boolean = false;
  @State @Watch('onCatRefreshChange') catRefreshing: boolean[] = [false, false, false, false, false];
  private repo: ForumRepository = ForumRepository.getInstance();
  private prefs: PreferencesManager = PreferencesManager.getInstance();
  private blockRepo: BlockRepository = BlockRepository.getInstance();
  private signedForumIds: Set<number> = new Set();
  private scroller: Scroller = new Scroller();
  private hotScroller: Scroller = new Scroller();
  private goodScroller: Scroller = new Scroller();
  private tabBarScroller: Scroller = new Scroller();

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
      console.warn('TiebaLite: ForumPage initTopInset failed ' + JSON.stringify(e));
    }
  }

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.forumName = params?.forumName || '';
    this.forumId = parseInt(params?.forumId || '0');
    console.info('TiebaLite: ForumPage name=' + this.forumName + ' id=' + this.forumId);
    this.initTopInset();
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
    this.onGripSideChanged();
    void this.blockRepo.ensureLoaded();
    void this.syncSortFromPrefs();
    this.loadThreads();
    if (this.forumId > 0) { this.loadForumRule(); }
  }

  private async syncSortFromPrefs(): Promise<void> {
    try {
      const v = await this.prefs.getInt('forum_sort', 0);
      if (v !== this.sortType) {
        this.sortType = v;
        this.page = 1;
        this.loadThreads();
      }
    } catch (e) {
      console.warn('TiebaLite: syncSortFromPrefs failed ' + JSON.stringify(e));
    }
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
    void this.syncSortFromPrefs();
  }

  onPageHide(): void {
    const v = AppStorage.get<number>('pageHideTick') || 0;
    AppStorage.SetOrCreate('pageHideTick', v + 1);
  }

  private onRefreshStateChange0(): void {
    if (this.isRefreshing0) {
      this.pullRefreshing = true;
      void this.onPullRefresh0();
    } else {
      this.pullRefreshing = false;
      this.pullDistance = 0;
    }
  }
  private onRefreshStateChange1(): void {
    if (this.isRefreshing1) {
      this.pullRefreshing = true;
      void this.onPullRefresh1();
    } else {
      this.pullRefreshing = false;
      this.pullDistance = 0;
    }
  }
  private onRefreshStateChangeGood(): void {
    if (this.isRefreshingGood) {
      this.pullRefreshing = true;
      void this.onPullRefreshGood();
    } else {
      this.pullRefreshing = false;
      this.pullDistance = 0;
    }
  }

  private onCatRefreshChange(): void {
    const ci = this.catRefreshing.findIndex((v: boolean): boolean => v);
    if (ci >= 0) {
      this.pullRefreshing = true;
      void this.loadCategoryThreads(ci, 1).then(() => {
        this.catRefreshing.splice(ci, 1, false);
        this.pullRefreshing = false;
      }, () => {
        this.catRefreshing.splice(ci, 1, false);
        this.pullRefreshing = false;
      });
    } else {
      this.pullRefreshing = false;
      this.pullDistance = 0;
    }
  }

  async onPullRefresh0(): Promise<void> {
    this.page = 1;
    this.hasMore = true;
    await this.loadThreads();
    this.isRefreshing0 = false;
  }

  async onPullRefresh1(): Promise<void> {
    this.rightHotPage = 1;
    this.rightHotHasMore = true;
    await this.loadRightHotThreads();
    this.isRefreshing1 = false;
  }

  async onPullRefreshGood(): Promise<void> {
    this.goodPage = 1;
    this.goodHasMore = true;
    await this.loadGoodThreads();
    this.isRefreshingGood = false;
  }

  async loadForumRule(): Promise<void> {
    try {
      const data = await this.repo.loadForumRule(this.forumId);
      if (data) {
        const ruleData = (data.data as Dict) || data;
        console.info('TiebaLite: forumRuleDetailKeys=' + Object.keys(ruleData).join(','));
        const ruleInfo = (ruleData.forum_rule_detail || ruleData.forumRuleDetail || ruleData.forum_rule || ruleData.forumRule || ruleData.rule || ruleData.forum_rule_info || ruleData.forumRuleInfo || ruleData) as Dict;
        const rt = getStr(ruleInfo, 'title', 'ruleTitle', 'rule_title', 'headLine', 'head_line', 'name', 'ruleName', 'rule_name');
        console.info('TiebaLite: forumRuleDetailTitle=' + (rt || 'none'));
        if (rt) {
          this.forumRule = ruleInfo;
          this.ruleTitle = rt;
        }
      }
    } catch (e) {
      console.info('TiebaLite: loadForumRule failed: ' + String(e));
    }
  }

  private parseForumTabs(d: Dict): void {
    try {
      const tabInfo = (d.nav_tab_info || d.tab_info || d.navTabInfo || {}) as Dict;
      console.info('TiebaLite: tabInfoRaw=' + JSON.stringify(tabInfo).substring(0, 500));
      const tabs = tabInfo.tab;
      if (!tabs || !Array.isArray(tabs) || tabs.length === 0) {
        this.forumTabs = [];
        return;
      }
      const list: ForumTab[] = [];
      for (const t of tabs as Dict[]) {
        const tid = getNum(t, 'tab_id', 'id', 'tabId');
        const name = getStr(t, 'tab_name', 'name', 'tabName');
        const tabType = getNum(t, 'tab_type', 'tabType');
        const isGen = getNum(t, 'is_general_tab', 'isGeneralTab');
        if (tid > 0 && name) {
          list.push({ tabId: tid, tabName: name, tabType: tabType, isGeneralTab: isGen });
        }
      }
      // 仅保留普通分区（对齐 Android filterNavTab：isGeneralTab=1 && tabType=15），
      // 其余特殊 tab（直播等）不进入分区列表
      const generalList = list.filter((t: ForumTab) => t.isGeneralTab === 1 && t.tabType === 15);
      const changed = generalList.length !== this.forumTabs.length
        || generalList.some((t: ForumTab, i: number) => {
          const old = this.forumTabs[i];
          return !old || old.tabId !== t.tabId || old.tabName !== t.tabName;
        });
      this.forumTabs = generalList.length > 0 ? generalList : [];
      if (changed) {
        const n = this.forumTabs.length;
        this.catThreads = [];
        this.catPage = [];
        this.catHasMore = [];
        this.catLoading = [];
        this.catError = [];
        this.catLastId = [];
        this.catScrollers = [];
        for (let i = 0; i < n; i++) {
          this.catThreads.push([]);
          this.catPage.push(1);
          this.catHasMore.push(true);
          this.catLoading.push(false);
          this.catError.push('');
          this.catLastId.push(0);
          this.catScrollers.push(new Scroller());
        }
        this.tabItemWidths = new Array(3 + n).fill(0);
        this.updateStripIndicatorOffset();
      }
    } catch (e) {
      console.info('TiebaLite: parseForumTabs failed: ' + String(e));
    }
  }

  private setArr<T>(arr: T[], idx: number, val: T): T[] {
    const copy = arr.slice();
    copy[idx] = val;
    return copy;
  }

  private getCatScroller(ci: number): Scroller {
    while (this.catScrollers.length <= ci) {
      this.catScrollers.push(new Scroller());
    }
    return this.catScrollers[ci];
  }

  private async loadCategoryThreads(ci: number, pn: number, loadMore: boolean = false): Promise<void> {
    if (ci < 0 || ci >= this.forumTabs.length) return;
    if (this.catLoading[ci]) return;
    const tab = this.forumTabs[ci];
    this.catLoading = this.setArr(this.catLoading, ci, true);
    this.catError = this.setArr(this.catError, ci, '');
    try {
      const data: Dict = await this.repo.loadGeneralTabList(
        this.forumId, this.forumName,
        tab.tabId, tab.tabName, tab.tabType, tab.isGeneralTab,
        pn, this.sortType, pn > 1 ? (this.catLastId[ci] || 0) : 0
      );
      const d = (data.data as Dict) || data;
      const list: Dict[] = (d.thread_list as Dict[] | undefined) || [];
      const visibleList = list.filter((t: Dict) => !this.isThreadBlocked(t));
      const hasMore = getNum(d, 'has_more') === 1 || list.length > 0;
      const cur = loadMore ? (this.catThreads[ci] || []) : [];
      this.catThreads = this.setArr(this.catThreads, ci, cur.concat(visibleList));
      this.catHasMore = this.setArr(this.catHasMore, ci, hasMore);
      this.catPage = this.setArr(this.catPage, ci, pn);
      if (list.length > 0) {
        const last = list[list.length - 1];
        this.catLastId = this.setArr(this.catLastId, ci, Number(getStr(last, 'id', 'tid', 'threadId', 'thread_id') || 0));
      }
    } catch (e) {
      console.error('TiebaLite: loadCategoryThreads error=' + String(e));
      this.catError = this.setArr(this.catError, ci, '加载失败');
    } finally {
      this.catLoading = this.setArr(this.catLoading, ci, false);
    }
  }

  async loadThreads(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      if (this.blockRepo.isForumBlocked(this.forumName)) {
        this.error = '该贴吧已被屏蔽';
        this.loading = false;
        return;
      }
      const data: Dict = await this.repo.loadFrsPage(this.forumName, 1, this.sortType, 0, 0);
      console.info('TiebaLite: ForumPage error_code=' + JSON.stringify(data.error_code) + ' sortType=' + this.sortType + ' keys=' + Object.keys(data).join(','));
      const errCode = data.error_code;
      if (errCode !== undefined && errCode !== null && String(errCode) !== '0' && String(errCode) !== '300000') {
        this.error = String(data.error_msg || 'Error (code=' + String(errCode) + ')');
        return;
      }
      const d = (data.data as Dict) || data;
      const forum = d.forum as Dict || {};
      if (!this.forumAvatar) {
        this.forumAvatar = getStr(d, 'forumAvatar', 'forum_avatar', 'forumAvatarUrl', 'forum_avatar_url');
        if (!this.forumAvatar && forum) this.forumAvatar = getStr(forum, 'avatar', 'head', 'forum_avatar', 'forumAvatar', 'icon', 'img', 'picture');
        if (!this.forumAvatar && this.forumName) {
          this.forumAvatar = 'http://tb.himg.baidu.com/sys/portraitn/item/' + this.forumName + '?time=' + Date.now();
        }
      }
      this.parseForumTabs(d);
      console.info('TiebaLite: dKeys=' + Object.keys(d).join(',') + ' forum exists=' + (d.forum !== undefined) + ' forumKeys=' + Object.keys(forum).join(','));
      // FrsPageResponseData.toData: liked = it.is_like == 1  (it = forum)
      this.isLiked = getNum(forum, 'is_like') === 1 || getStr(forum, 'is_like') === '1'
        || getNum(d, 'is_like') === 1 || getStr(d, 'is_like') === '1';
      console.info('TiebaLite: isLiked=' + this.isLiked + ' forum.is_like=' + getStr(forum, 'is_like'));
      // signed = forum.sign_in_info.user_info.is_sign_in == 1
      const signInfo = (forum.sign_in_info || forum.signInInfo || {}) as Dict;
      const signUserInfo = (signInfo.user_info || signInfo.userInfo || {}) as Dict;
      const isSigned = getNum(signUserInfo, 'is_sign_in') === 1 || getStr(signUserInfo, 'is_sign_in') === '1';
      this.consecutiveSignDays = getNum(signUserInfo, 'cont_sign_num', 'sign_consecutive_days', 'consecutive_sign_days', 'total_sign_days');
      if (isSigned) {
        this.signedToday = true;
        this.signedForumIds.add(this.forumId);
      } else {
        // fallback: AppStorage check
        const signedArr = AppStorage.Get<number[]>('signedForumIdsArr') || [];
        this.signedToday = signedArr.indexOf(this.forumId) >= 0;
        this.signedForumIds = new Set(signedArr);
      }
      console.info('TiebaLite: signedToday=' + this.signedToday + ' signInfoKeys=' + Object.keys(signInfo).join(',') + ' signUserKeys=' + Object.keys(signUserInfo).join(','));
      const userList = d.user_list;
      const userMap: Map<string, Dict> = new Map();
      if (userList && Array.isArray(userList)) {
        for (const u of userList as Dict[]) {
          const uid = getStr(u, 'id', 'user_id', 'uid');
          if (uid) userMap.set(uid, u);
        }
      }
      // extract threads from response data
      const allThreads = this.extractThreads(d, userMap);
      // 检查thread_list里的s_top字段(proto字段 isTop/int32 isTop=9)
      const pinned = allThreads.filter((t: Dict) => {
        const top = getStr(t, 'is_top', 'isTop') || getNum(t, 'is_top', 'isTop');
        const topTypes = getNum(t, 'top_types', 'topTypes');
        return top === '1' || top === 1 || topTypes === 1;
      });
      const topThreadsAll = pinned.length > 0 ? pinned : this.extractTopThreads(d, data);
      this.topThreads = topThreadsAll.filter((t: Dict) => !this.isThreadBlocked(t));
      console.info('TiebaLite: topThreads=' + this.topThreads.length + ' pinnedByIsTop=' + pinned.length + ' thread0.is_top=' + (allThreads.length > 0 ? getStr(allThreads[0], 'is_top', 'isTop') : 'none') + ' dKeys=' + Object.keys(d).join(','));
      // forumRule from d.forum_rule or data.forum_rule (FrsPage proto field 105: ForumRuleStatus)
      const forumRuleInResp = (d.forum_rule || data.forum_rule || d.forumRule || data.forumRule || d.rule || data.rule || d.forum_rule_info || data.forum_rule_info || d.forumRuleInfo || data.forumRuleInfo || d.rule_info || data.rule_info) as Dict;
      console.info('TiebaLite: forumRuleRaw=' + (forumRuleInResp ? JSON.stringify(forumRuleInResp).substring(0, 300) : 'none'));
      if (forumRuleInResp && !this.forumRule) {
        const hasRule = getNum(forumRuleInResp, 'has_forum_rule', 'hasForumRule', 'has_rule', 'hasRule');
        const rt = getStr(forumRuleInResp, 'title', 'ruleTitle', 'rule_title', 'name', 'ruleName', 'rule_name');
        if (rt && hasRule === 1) {
          this.forumRule = forumRuleInResp;
          this.ruleTitle = rt;
        }
      }
      this.threads = allThreads.filter((t: Dict) => !this.isThreadBlocked(t));
      if (this.threads.length > 0) {
        const ft = this.threads[0];
        console.info('TiebaLite: first processed thread keys=' + Object.keys(ft).join(',') + ' hasAuthor=' + (ft.author !== undefined) + ' authorKeys=' + (ft.author ? Object.keys(ft.author).join(',') : 'none'));
        const author = ft.author as Dict | undefined;
        if (author) {
          console.info('TiebaLite: author name=' + (author.name || author.nameShow || author.name_show || 'unknown') + ' portrait=' + (author.portrait || 'none'));
        }
        // try to find ANY name-like field at ANY level
        const allKeys = Object.keys(ft);
        for (const k of allKeys) {
          const v = ft[k];
          if (typeof v === 'string' && v.length > 0 && v.length < 50 && (k.includes('name') || k.includes('author') || k.includes('user'))) {
            console.info('TiebaLite: found name-like field: ' + k + '=' + v);
          }
        }
      }
      const topIds = new Set(this.topThreads.map((t: Dict) => getStr(t, 'id', 'tid', 'threadId', 'thread_id')));
      if (topIds.size > 0) {
        this.threads = this.threads.filter((t: Dict) => !topIds.has(getStr(t, 'id', 'tid', 'threadId', 'thread_id')));
      }
      if (this.threads.length === 0 && this.topThreads.length === 0) {
        console.info('TiebaLite: ForumPage empty, sortType=' + this.sortType + ' keys=' + Object.keys(d).join(','));
        if (d.thread_list && Array.isArray(d.thread_list)) {
          console.info('TiebaLite: thread_list has ' + (d.thread_list as Dict[]).length + ' items');
        }
        if (d.top_thread_list && Array.isArray(d.top_thread_list)) {
          console.info('TiebaLite: top_thread_list has ' + (d.top_thread_list as Dict[]).length + ' items');
        }
      }
    } catch (e) {
      console.error('TiebaLite: ForumPage error=' + String(e));
      this.error = '加载失败';
    } finally {
      this.loading = false;
    }
  }

async loadRightHotThreads(loadMore: boolean = false): Promise<void> {
    if (this.hotLoading) return;
    this.hotLoading = true;
    try {
      const pg = loadMore ? this.rightHotPage + 1 : 1;
      const data: Dict = await this.repo.loadFrsPage(this.forumName, pg, 0, 2);
      const d = (data.data as Dict) || data;
      const userList = d.user_list;
      const userMap: Map<string, Dict> = new Map();
      if (userList && Array.isArray(userList)) {
        for (const u of userList as Dict[]) {
          const uid = getStr(u, 'id', 'user_id', 'uid');
          if (uid) userMap.set(uid, u);
        }
      }
      const allThreads = this.extractThreads(d, userMap);
      const visibleThreads = allThreads.filter((t: Dict) => !this.isThreadBlocked(t));
      if (loadMore) {
        this.rightHotThreads = this.rightHotThreads.concat(visibleThreads);
        this.rightHotPage = pg;
      } else {
        this.rightHotThreads = visibleThreads;
        this.rightHotPage = 1;
      }
      this.rightHotHasMore = allThreads.length > 0;
    } catch (e) {
      console.error('TiebaLite: loadRightHotThreads error=' + String(e));
    } finally {
      this.hotLoading = false;
    }
  }

  async loadGoodThreads(loadMore: boolean = false): Promise<void> {
    if (this.goodLoading) return;
    this.goodLoading = true;
    this.goodError = '';
    try {
      const pg = loadMore ? this.goodPage + 1 : 1;
      // loadType=1 且 is_good=1，拉取精华帖
      const data: Dict = await this.repo.loadFrsPage(this.forumName, pg, 0, 1);
      const d = (data.data as Dict) || data;
      const userList = d.user_list;
      const userMap: Map<string, Dict> = new Map();
      if (userList && Array.isArray(userList)) {
        for (const u of userList as Dict[]) {
          const uid = getStr(u, 'id', 'user_id', 'uid');
          if (uid) userMap.set(uid, u);
        }
      }
      const allThreads = this.extractThreads(d, userMap);
      const topIds = new Set(this.topThreads.map((t: Dict) => getStr(t, 'id', 'tid', 'threadId', 'thread_id')));
      const filtered = allThreads.filter((t: Dict) => !topIds.has(getStr(t, 'id', 'tid', 'threadId', 'thread_id')) && !this.isThreadBlocked(t));
      if (loadMore) {
        this.goodThreads = this.goodThreads.concat(filtered);
        this.goodPage = pg;
      } else {
        this.goodThreads = filtered;
        this.goodPage = 1;
      }
      this.goodHasMore = filtered.length > 0;
    } catch (e) {
      console.error('TiebaLite: loadGoodThreads error=' + String(e));
      this.goodError = '加载失败';
    } finally {
      this.goodLoading = false;
    }
  }

  onTabChange(index: number): void {
    animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
      this.selectedTab = index;
      this.tabProgress = index;
      this.updateStripIndicatorOffset();
    });
    this.scrollStripToIndex(index);
    this.loadPageIfNeeded(index);
  }

  private loadPageIfNeeded(index: number): void {
    if (index === 0) {
      if (this.threads.length === 0 && !this.loading) {
        void this.loadThreads();
      }
    } else if (index === 1) {
      if (this.goodThreads.length === 0 && !this.goodLoading) {
        void this.loadGoodThreads();
      }
    } else if (index === 2) {
      if (this.rightHotThreads.length === 0 && !this.hotLoading) {
        void this.loadRightHotThreads();
      }
    } else {
      const ci = index - 3;
      if (ci < this.forumTabs.length && (this.catThreads[ci] || []).length === 0 && !this.catLoading[ci]) {
        void this.loadCategoryThreads(ci, 1);
      }
    }
  }

  private getThreadUid(t: Dict): number {
    const author = t.author as Dict | undefined;
    const fromAuthor = author ? getStr(author, 'id', 'user_id', 'uid', 'userId') : '';
    if (fromAuthor) return Number(fromAuthor);
    return Number(getStr(t, 'authorId', 'author_id', 'authorUid', 'author_uid', 'uid', 'userId', 'user_id') || 0);
  }

  private getThreadAbstract(t: Dict): string {
    const abs = t._abstract;
    if (Array.isArray(abs) && abs.length > 0) {
      const parts: string[] = [];
      for (const it of abs as Dict[]) {
        const c = getStr(it, 'c', 'text');
        if (c) parts.push(c);
      }
      return parts.join(' ');
    }
    return getStr(t, 'first_post_content', 'firstPostContent', '_abstract', 'abstract', 'abstractText', 'content', 'excerpt', 'richAbstract', 'rich_abstract');
  }

  private isThreadBlocked(t: Dict): boolean {
    return this.blockRepo.isThreadBlocked(
      this.forumName,
      this.getThreadUid(t),
      getStr(t, 'title', 'threadTitle', 'thread_title'),
      this.getThreadAbstract(t)
    );
  }

  private getThreadSortTime(thread: Dict, sortType: number): number {
    const field = sortType === 6
      ? getStr(thread, 'lastTimeInt', 'lastTime', 'last_time', 'lastTimeStr', 'last_time_str')
      : getStr(thread, 'createTime', 'create_time');
    if (!field) return 0;
    const ts = Number(field);
    if (!isNaN(ts) && ts > 0) return ts > 1e12 ? ts : ts * 1000;
    const d = new Date(field);
    return isNaN(d.getTime()) ? 0 : d.getTime();
  }

  private compareBySortTime(a: Dict, b: Dict, sortType: number): number {
    return this.getThreadSortTime(a, sortType) - this.getThreadSortTime(b, sortType);
  }

  private getWinWidth(): number {
    try {
      const d = display.getDefaultDisplaySync();
      if (d && d.width > 0) return d.width / d.densityPixels;
    } catch (e) { }
    return 360;
  }

  private tabItemW(i: number): number {
    if (i < 0 || i >= this.tabItemWidths.length) return 24;
    return this.tabItemWidths[i] > 0 ? this.tabItemWidths[i] : 24;
  }

  private tabLeftOf(i: number): number {
    let l = 8;
    for (let k = 0; k < i; k++) l += this.tabItemW(k);
    return l;
  }

  private tabCenterOf(i: number): number {
    return this.tabLeftOf(i) + this.tabItemW(i) / 2;
  }

  private stripContentWidth(): number {
    const n = this.getStripTabs().length;
    let w = 8;
    for (let k = 0; k < n; k++) w += this.tabItemW(k);
    return w + 8;
  }

  // 标签条跟随滑动：当前(插值的)标签居中于可见区域内
  private scrollStripToProgress(p: number, animated: boolean = false): void {
    const n = this.getStripTabs().length;
    if (n === 0 || this.tabBarWidth <= 0) return;
    const clamped = Math.max(0, Math.min(p, n - 1));
    const i0 = Math.floor(clamped);
    const i1 = Math.min(i0 + 1, n - 1);
    const frac = clamped - i0;
    const center = this.tabCenterOf(i0) + (this.tabCenterOf(i1) - this.tabCenterOf(i0)) * frac;
    const maxScroll = Math.max(0, this.stripContentWidth() - this.tabBarWidth);
    const target = Math.max(0, Math.min(center - this.tabBarWidth / 2, maxScroll));
    if (animated) {
      this.tabBarScroller.scrollTo({ xOffset: target, yOffset: 0, animation: { duration: 200, curve: Curve.FastOutSlowIn } });
    } else {
      this.tabBarScroller.scrollTo({ xOffset: target, yOffset: 0 });
    }
  }

  private scrollStripToIndex(index: number): void {
    this.scrollStripToProgress(index, true);
  }

  private updateStripIndicatorOffset(): void {
    const tabs = this.getStripTabs();
    const n = tabs.length;
    if (n === 0) return;
    const wget = (i: number): number => this.tabItemW(i);
    const leftOf = (i: number): number => this.tabLeftOf(i);
    const clamped = Math.max(0, Math.min(this.tabProgress, n - 1));
    const i0 = Math.floor(clamped);
    const i1 = Math.min(i0 + 1, n - 1);
    const frac = clamped - i0;
    const w0 = wget(i0);
    const w1 = wget(i1);
    const baseW = w0 + (w1 - w0) * frac;
    // 指示条比文字略短（tab 内边距 20*2 + 额外 4 = 44），并保持1.2倍再回缩"动画
    const normW = Math.max(8, baseW - 44);
    const factor = 1 - Math.abs(frac - 0.5) * 2;
    this.indicatorWidth = normW + normW * factor;
    const l0 = leftOf(i0);
    const l1 = leftOf(i1);
    const center = l0 + (l1 - l0) * frac + baseW / 2;
    this.tabIndicatorOffset = center - this.indicatorWidth / 2;
  }

  private getStripTabs(): Dict[] {
    const tabs: Dict[] = [];
    tabs.push({ key: 'latest', name: '最新', kind: 'latest', id: 0 } as Dict);
    tabs.push({ key: 'good', name: '精华', kind: 'good', id: 2 } as Dict);
    tabs.push({ key: 'hot', name: '热门', kind: 'hot', id: 1 } as Dict);
    for (const t of this.forumTabs) {
      tabs.push({ key: 'cat_' + t.tabId, name: t.tabName, kind: 'cat', id: t.tabId } as Dict);
    }
    return tabs;
  }

  private getStripTabIndex(kind: string, id: number): number {
    const tabs = this.getStripTabs();
    for (let i = 0; i < tabs.length; i++) {
      if (getStr(tabs[i], 'kind') === kind && getNum(tabs[i], 'id') === id) return i;
      if (kind === 'cat' && getStr(tabs[i], 'kind') === 'cat' && getNum(tabs[i], 'id') === id) return i;
    }
    return 0;
  }

  private isStripActive(item: Dict): boolean {
    const kind = getStr(item, 'kind');
    if (kind === 'latest') return this.selectedTab === 0;
    if (kind === 'good') return this.selectedTab === 1;
    if (kind === 'hot') return this.selectedTab === 2;
    return this.getStripTabIndex('cat', getNum(item, 'id')) === this.selectedTab;
  }

  private onStripTabClick(kind: string, id: number): void {
    if (kind === 'latest') {
      this.showSortDropdown = false;
      this.onTabChange(0);
    } else if (kind === 'good') {
      this.showSortDropdown = false;
      this.onTabChange(1);
    } else if (kind === 'hot') {
      this.showSortDropdown = false;
      this.onTabChange(2);
    } else if (kind === 'cat') {
      this.showSortDropdown = false;
      this.onTabChange(this.getStripTabIndex('cat', id));
    }
  }

  @Builder
  sortDropdownBuilder() {
    Column() {
      this.sortOptionRow(1)
      Divider().height(0.75).color(this.isDark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.1)').width('80%')
      this.sortOptionRow(6)
    }
    .width('100%')
    .padding({ left: 3, right: 3, top: 3, bottom: 3 })
    .backgroundColor(blendWithBg(this.primaryColor, 0.08, this.isDark, '#1E1E1E'))
    .borderRadius(4)
  }

  private getSortNameByValue(sortValue: number): string {
    return sortValue === 6 ? '按回复时间' : '按发布时间';
  }

  @Builder
  sortOptionRow(opt: number) {
    Row() {
      Text(this.getSortNameByValue(opt))
        .fontFamily(this.appFontFamily)
        .fontSize(Math.round(15 * this.fontScale))
        .fontWeight(this.sortType === opt ? FontWeight.Bold : FontWeight.Regular)
        .fontColor(this.sortType === opt ? textAccent(this.primaryColor, this.isDark) : textPrimary(this.isDark))
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
      if (this.sortType === opt) {
        Image($r('app.media.ic_check_single'))
          .width(Math.round(16 * this.fontScale)).height(Math.round(16 * this.fontScale))
          .fillColor(textAccent(this.primaryColor, this.isDark))
          .margin({ left: 4 })
      } else {
        Row().width(Math.round(20 * this.fontScale))
      }
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 8, bottom: 8 })
    .backgroundColor(this.sortType === opt ? blendWithBg(this.primaryColor, 0.18, this.isDark, '#1E1E1E') : Color.Transparent)
    .borderRadius(4)
    .onClick(() => {
      if (this.sortType !== opt) {
        this.sortType = opt; this.page = 1; void this.loadThreads();
        void this.prefs.putInt('forum_sort', opt).catch((e: Error) => { console.warn('TiebaLite: save forum_sort failed ' + JSON.stringify(e)); });
      }
      this.showSortDropdown = false;
    })
  }

  build() {
    Stack() {
      Column() {
      }
        .width('100%').height('100%')
        .backgroundColor(pageBg(this.isDark))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      Column() {
      Column() {
      Column() {
      Row() {
        Image($r('app.media.ic_arrow_back')).width(Math.round(22 * this.fontScale)).height(Math.round(22 * this.fontScale)).fillColor(textPrimary(this.isDark)).onClick(() => NavigationHelper.back())
        Avatar({ portrait: buildPortraitUrl(this.forumAvatar), avatarSize: 30, defaultName: this.forumName })
          .width(30).height(30).margin({ left: 12 })
        Text(this.forumName).fontFamily(this.appFontFamily).fontSize(18).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark)).margin({ left: 8 }).layoutWeight(1)
        Blank()
        if (this.signedToday) {
          Text(this.consecutiveSignDays > 0 ? '已签' + this.consecutiveSignDays + '天' : '已签到')
            .fontFamily(this.appFontFamily).fontSize(Math.round(13 * this.fontScale)).fontColor(textSecondary(this.isDark))
            .margin({ right: 10 })
        } else {
          Text('签到')
            .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textAccent(this.primaryColor, this.isDark)).fontWeight(FontWeight.Medium)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor(blendWithBg(this.primaryColor, 0.1, this.isDark)).borderRadius(4)
            .margin({ right: 10 })
            .onClick(() => { this.doSign(); })
        }
        Image($r('app.media.ic_search')).width(Math.round(34 * this.fontScale)).height(Math.round(34 * this.fontScale)).fillColor(textSecondary(this.isDark))
          .padding(6).margin({ right: 4 })
          .onClick(() => {
            NavigationHelper.navigate('pages/search/ForumSearchPage', { forumName: this.forumName });
          })
        Image($r('app.media.ic_more_vert')).width(Math.round(28 * this.fontScale)).height(Math.round(28 * this.fontScale)).fillColor(textSecondary(this.isDark))
          .padding({ left: 8, right: 8, top: 6, bottom: 6 })
          .onClick(() => this.showForumMenu())
      }
      .padding({ left: 12, right: 8, top: this.headerCollapsed ? 0 : 8, bottom: this.headerCollapsed ? 0 : 8 }).width('100%')
      }
      .width('100%')
      .height(this.headerCollapsed ? 0 : this.nameRowHeight)
      .clip(true)
      .opacity(this.headerCollapsed ? 0 : 1)

        Row() {
        Column() {
          Column() {
            Row().width(18).height(2).borderRadius(1).backgroundColor(this.primaryColor)
            Row().width(13).height(2).borderRadius(1).backgroundColor(this.primaryColor).margin({ top: 3 })
            Row().width(8).height(2).borderRadius(1).backgroundColor(this.primaryColor).margin({ top: 3 })
          }
          .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        }
        .width(44).height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .onClick(() => { this.showSortDropdown = !this.showSortDropdown; }, 12)
        .bindPopup(this.showSortDropdown, {
          builder: (): void => { this.sortDropdownBuilder(); },
          placement: Placement.BottomRight,
          enableArrow: false,
          popupColor: blendWithBg(this.primaryColor, 0.08, this.isDark, '#1E1E1E'),
          width: Math.round(120 * this.fontScale),
          offset: { x: 22, y: 6 },
          mask: false,
          autoCancel: true,
          onStateChange: (event): void => { this.showSortDropdown = event.isVisible; }
        })

        Scroll(this.tabBarScroller) {
          Stack({ alignContent: Alignment.BottomStart }) {
            Row() {
              ForEach(this.getStripTabs(), (item: Dict, index: number) => {
                Column() {
                  Row() {
                    Text(getStr(item, 'name'))
                      .fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale))
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      .fontColor(this.isStripActive(item) ? textAccent(this.primaryColor, this.isDark) : textSecondary(this.isDark))
                      .fontWeight(this.isStripActive(item) ? FontWeight.Bold : FontWeight.Regular)
                  }
                  .padding({ left: 20, right: 20, top: 12, bottom: 12 })
                  .onAreaChange((_old: Area, newArea: Area): void => {
                    const w = newArea.width as number;
                    if (w > 0 && Math.abs(w - (this.tabItemWidths[index] || 0)) > 0.5) {
                      this.tabItemWidths[index] = w;
                      this.updateStripIndicatorOffset();
                    }
                  })
                  .onClick(() => { this.onStripTabClick(getStr(item, 'kind'), getNum(item, 'id')); }, 12)
                }
              }, (tab: Dict) => getStr(tab, 'key'))
            }
            .padding({ left: 8, right: 8 })

            Column()
              .width(this.indicatorWidth).height(3).backgroundColor(this.primaryColor).borderRadius(2)
              .margin({ left: this.tabIndicatorOffset })
              .animation({ duration: 250, curve: Curve.FastOutSlowIn })
          }
          .height(44)
        }
          .scrollBar(BarState.Off)
        .layoutWeight(1)
        .scrollable(ScrollDirection.Horizontal)
        .onAreaChange((_old: Area, newArea: Area) => {
          const w = newArea.width as number;
          if (w > 0 && Math.abs(w - this.tabBarWidth) > 0.5) {
            this.tabBarWidth = w;
            this.updateStripIndicatorOffset();
            this.scrollStripToIndex(this.selectedTab);
          }
        })
      }
      .width('100%').height(44)
      }
      .width('100%')
      .position({ x: 0, y: 0 })
      .zIndex(2)
      .backgroundColor(this.cardStyle === 1 ? withAlpha((this.cardStyle === 1 ? darkenColor(pageBg(this.isDark), this.headerTint / 100) : pageBg(this.isDark)), 1 - this.headerAlpha / 100) : withAlpha(pageBg(this.isDark), 1 - this.headerAlpha / 100))
      .backdropBlur(60)
      .border({ width: { bottom: 1 }, color: blendWithBg(this.primaryColor, 0.15, this.isDark, '#1E1E1E') })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        Swiper() {
          ForEach(this.getStripTabs(), (item: Dict, si: number) => {
            Column() {
              if (si === 0) {
                this.latestPageContent()
              } else if (si === 1) {
                this.goodPageContent()
              } else if (si === 2) {
                this.hotPageContent()
              } else {
                this.catPageContent(si - 3)
              }
            }
            .width('100%').height('100%').justifyContent(FlexAlign.Start)
          }, (tab: Dict) => getStr(tab, 'key'))
        }
        .layoutWeight(1).width('100%').clip(false).loop(false)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .index(this.selectedTab)
        .indicator(this.showSwiperDots)
      .onChange((index: number) => {
        if (this.selectedTab === index) return;
        this.selectedTab = index;
        this.scrollStripToIndex(index);
        this.loadPageIfNeeded(index);
      })
      .onAnimationStart((_index: number, targetIndex: number, _extraInfo: SwiperAnimationEvent) => {
        animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
          this.tabProgress = targetIndex;
          this.updateStripIndicatorOffset();
        });
        this.scrollStripToProgress(targetIndex, true);
      })
      .onGestureSwipe((index: number, extraInfo: SwiperAnimationEvent) => {
        const pageWidth = this.getWinWidth();
        const n = this.getStripTabs().length;
        const raw = index + (-extraInfo.currentOffset) / pageWidth;
        this.tabProgress = Math.max(0, Math.min(raw, n - 1));
        this.updateStripIndicatorOffset();
        this.scrollStripToProgress(this.tabProgress);
      })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start).backgroundColor(pageBg(this.isDark)).expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
      .onClick(() => { this.showSortDropdown = false; })

      if (this.showFabMenu) {
        Column()
          .width('100%').height('100%')
          .onClick(() => { this.showFabMenu = false; })
      }

      Column() {
        if (this.showFabMenu) { this.FabMenuItems() }
        this.FabButton()
      }
      .alignItems(this.fabLeft ? HorizontalAlign.Start : HorizontalAlign.End)
      .position({ bottom: 32, right: 16 })
      .translate({ x: this.fabVisible ? (this.fabLeft ? -(this.getWinWidth() - 84) : 0) : (this.fabLeft ? -(this.getWinWidth() - 84) - 96 : 96) })
      .hitTestBehavior(this.fabVisible ? HitTestMode.Default : HitTestMode.None)
    }
    .width('100%').height('100%').backgroundColor(pageBg(this.isDark)).expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
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
  latestPageContent() {
    if (this.reduceEffects) {
      PullToRefresh({
        reduceEffects: true,
        scroller: this.scroller,
        iconTopOffset: 138,
        isRefreshing: this.isRefreshing0,
        onRefresh: (): void => { this.isRefreshing0 = true; },
        onTimeout: (): void => { this.isRefreshing0 = false; }
      }) {
        this.latestScrollContent()
      }
    } else {
      PullToRefresh({
        scroller: this.scroller,
        iconTopOffset: 138,
        isRefreshing: this.isRefreshing0,
        onRefresh: (): void => { this.isRefreshing0 = true; },
        onTimeout: (): void => { this.isRefreshing0 = false; }
      }) {
        this.latestScrollContent()
      }
    }
  }

  @Builder
  latestScrollContent() {
      Scroll(this.scroller) {
        Column() {
          Blank().height(this.contentTopPad())
          if (this.loading && this.threads.length === 0 && this.topThreads.length === 0) {
            Column() {
              GearLoading({ gearSize: 40, color: '#4477E0' })
              Text('Loading...').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark)).margin({ top: 16 })
            }
            .width('100%').height(400).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
          } else if (this.error.length > 0 && this.threads.length === 0 && this.topThreads.length === 0) {
            Column() {
              Text('!').fontFamily(this.appFontFamily).fontSize(Math.round(48 * this.fontScale)).fontColor('#FF4444')
              Text(this.error).fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontColor(textSecondary(this.isDark)).margin({ top: 16 })
              Button('重试').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor('#FFFFFF').backgroundColor('#4477E0').borderRadius(20).width(120).height(40).margin({ top: 24 })
                .onClick(() => { void this.loadThreads(); })
            }
            .width('100%').height(400).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
          } else {
            if (this.topThreads.length > 0 || (this.forumRule && this.ruleTitle)) {
              Column() { this.topSectionContent() }
              .width('100%')
              .backgroundColor(blendWithBg(this.primaryColor, 0.08, this.isDark, '#1E1E1E'))
              .borderRadius(10)
              .margin({ left: 12, right: 12, top: 8, bottom: 4 })
              .shadow({ radius: 2, color: shadowColor(this.isDark), offsetY: 1 })
              Divider().height(0.75).color(pageBg(this.isDark)).margin({ left: 56, right: 56 })
            }

            ForEach(this.threads, (thread: Dict, index: number) => {
              this.threadCard(thread)
            })
            if (this.loadingMore) {
              GearLoading({ gearSize: 24, color: darkenColor(this.primaryColor, 0.2), text: '加载更多...' })
            }
            Column().height(44)
          }
        }
        .width('100%')
      }
        .scrollBar(BarState.Off)
      .width('100%').layoutWeight(1).align(Alignment.TopStart)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .backgroundColor(pageBg(this.isDark))
      .edgeEffect(EdgeEffect.None)
      .onReachEnd(() => {
        if (this.hasMore) { this.page++; void this.loadMore(); }
      })
      .onDidScroll(() => { this.handleFabScroll(this.scroller); this.handleHeaderScroll(this.scroller); })
    }

  @Builder
  hotPageContent() {
    if (this.hotLoading && this.rightHotThreads.length === 0) {
      LoadingState({ message: '加载中...' })
    } else if (this.rightHotThreads.length === 0) {
      Column() {
        Text('暂无热门帖').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark))
      }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    } else {
      if (this.reduceEffects) {
        PullToRefresh({
          reduceEffects: true,
          scroller: this.hotScroller,
        iconTopOffset: 138,
          isRefreshing: this.isRefreshing1,
          onRefresh: (): void => { this.isRefreshing1 = true; },
          onTimeout: (): void => { this.isRefreshing1 = false; }
        }) {
          this.hotScrollContent()
        }
      } else {
        PullToRefresh({
          scroller: this.hotScroller,
        iconTopOffset: 138,
          isRefreshing: this.isRefreshing1,
          onRefresh: (): void => { this.isRefreshing1 = true; },
          onTimeout: (): void => { this.isRefreshing1 = false; }
        }) {
          this.hotScrollContent()
        }
      }
    }
  }

  @Builder
  hotScrollContent() {
        Scroll(this.hotScroller) {
          Column() {
            Blank().height(this.contentTopPad())
            ForEach(this.rightHotThreads, (thread: Dict, index: number) => {
              this.threadCard(thread)
            })
            if (this.hotLoading) {
              GearLoading({ gearSize: 24, color: darkenColor(this.primaryColor, 0.2), text: '加载更多...' })
            }
            Column().height(44)
          }
          .width('100%')
        }
          .scrollBar(BarState.Off)
        .width('100%').layoutWeight(1).align(Alignment.TopStart)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .backgroundColor(pageBg(this.isDark))
        .edgeEffect(EdgeEffect.None)
        .onReachEnd(() => {
          if (this.rightHotHasMore) { void this.loadRightHotThreads(true); }
        })
        .onDidScroll(() => { this.handleFabScroll(this.hotScroller); this.handleHeaderScroll(this.hotScroller); })
      }

  @Builder
  goodPageContent() {
    if (this.goodLoading && this.goodThreads.length === 0) {
      LoadingState({ message: '加载中...' })
    } else if (this.goodError.length > 0 && this.goodThreads.length === 0) {
      Column() {
        Text('!').fontFamily(this.appFontFamily).fontSize(Math.round(48 * this.fontScale)).fontColor('#FF4444')
        Text(this.goodError).fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontColor(textSecondary(this.isDark)).margin({ top: 16 })
        Button('重试').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor('#FFFFFF').backgroundColor('#4477E0').borderRadius(20).width(120).height(40).margin({ top: 24 })
          .onClick(() => { void this.loadGoodThreads(); })
      }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    } else if (this.goodThreads.length === 0) {
      Column() {
        Text('暂无精华帖').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark))
      }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    } else {
      if (this.reduceEffects) {
        PullToRefresh({
          reduceEffects: true,
          scroller: this.goodScroller,
        iconTopOffset: 138,
          isRefreshing: this.isRefreshingGood,
          onRefresh: (): void => { this.isRefreshingGood = true; },
          onTimeout: (): void => { this.isRefreshingGood = false; }
        }) {
          this.goodScrollContent()
        }
      } else {
        PullToRefresh({
          scroller: this.goodScroller,
        iconTopOffset: 138,
          isRefreshing: this.isRefreshingGood,
          onRefresh: (): void => { this.isRefreshingGood = true; },
          onTimeout: (): void => { this.isRefreshingGood = false; }
        }) {
          this.goodScrollContent()
        }
      }
    }
  }

  @Builder
  goodScrollContent() {
        Scroll(this.goodScroller) {
          Column() {
            Blank().height(this.contentTopPad())
            ForEach(this.goodThreads, (thread: Dict, index: number) => {
              this.threadCard(thread)
            })
            if (this.goodLoading) {
              GearLoading({ gearSize: 24, color: darkenColor(this.primaryColor, 0.2), text: '加载更多...' })
            }
            Column().height(44)
          }
          .width('100%')
        }
          .scrollBar(BarState.Off)
        .width('100%').layoutWeight(1).align(Alignment.TopStart)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .backgroundColor(pageBg(this.isDark))
        .edgeEffect(EdgeEffect.None)
        .onReachEnd(() => {
          if (this.goodHasMore) { void this.loadGoodThreads(true); }
        })
        .onDidScroll(() => { this.handleFabScroll(this.goodScroller); this.handleHeaderScroll(this.goodScroller); })
      }

  @Builder
  catPageContent(ci: number) {
    if (this.catLoading[ci] && (this.catThreads[ci] || []).length === 0) {
      LoadingState({ message: '加载中...' })
    } else if ((this.catError[ci] || '').length > 0 && (this.catThreads[ci] || []).length === 0) {
      Column() {
        Text('!').fontFamily(this.appFontFamily).fontSize(Math.round(48 * this.fontScale)).fontColor('#FF4444')
        Text(this.catError[ci] || '加载失败').fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontColor(textSecondary(this.isDark)).margin({ top: 16 })
        Button('重试').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor('#FFFFFF').backgroundColor('#4477E0').borderRadius(20).width(120).height(40).margin({ top: 24 })
          .onClick(() => { void this.loadCategoryThreads(ci, 1); })
      }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    } else if ((this.catThreads[ci] || []).length === 0) {
      Column() {
        Text('暂无帖子').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark))
      }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    } else {
      if (this.reduceEffects) {
        PullToRefresh({
          reduceEffects: true,
          scroller: this.getCatScroller(ci),
          iconTopOffset: 138,
          isRefreshing: this.catRefreshing[ci],
          onRefresh: (): void => { this.catRefreshing.splice(ci, 1, true); },
          onTimeout: (): void => { this.catRefreshing.splice(ci, 1, false); }
        }) {
          this.catScrollContent(ci)
        }
      } else {
        PullToRefresh({
          scroller: this.getCatScroller(ci),
          iconTopOffset: 138,
          isRefreshing: this.catRefreshing[ci],
          onRefresh: (): void => { this.catRefreshing.splice(ci, 1, true); },
          onTimeout: (): void => { this.catRefreshing.splice(ci, 1, false); }
        }) {
          this.catScrollContent(ci)
        }
      }
    }
  }

  @Builder
  catScrollContent(ci: number) {
      Scroll(this.getCatScroller(ci)) {
        Column() {
          Blank().height(this.contentTopPad())
          ForEach(this.catThreads[ci] || [], (thread: Dict, index: number) => {
            this.threadCard(thread)
          })
          if (this.catLoading[ci]) {
            GearLoading({ gearSize: 24, color: darkenColor(this.primaryColor, 0.2), text: '加载更多...' })
          }
          Column().height(44)
        }
        .width('100%')
      }
        .scrollBar(BarState.Off)
      .width('100%').layoutWeight(1).align(Alignment.TopStart)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .backgroundColor(pageBg(this.isDark))
      .edgeEffect(EdgeEffect.None)
        .onReachEnd(() => {
          if (this.catHasMore[ci]) {
            void this.loadCategoryThreads(ci, (this.catPage[ci] || 1) + 1, true);
          }
        })
        .onDidScroll(() => { this.handleFabScroll(this.getCatScroller(ci)); this.handleHeaderScroll(this.getCatScroller(ci)); })
      }

  @Builder
  threadCard(thread: Dict) {
    ThreadCard({
      thread: thread,
      onCardClick: (): void => {
        NavigationHelper.navigate('pages/thread/ThreadPage', {
          threadId: getStr(thread, 'id', 'tid', 'threadId', 'thread_id'),
          forumId: String(this.forumId),
          forumName: this.forumName
        });
      },
      onLikeClick: (liked: boolean): void => {
        const tid = getStr(thread, 'id', 'tid', 'threadId', 'thread_id');
        if (tid) {
          const repo = PbPageRepository.getInstance();
          if (liked) repo.likePost(Number(tid), 0).catch(() => {});
          else repo.dislikePost(Number(tid), 0).catch(() => {});
        }
      }
    }).margin({ left: 16, right: 16, top: 6, bottom: 6 })
  }

  private openNewThread(): void {
    if (!AccountManager.getInstance().isLoggedIn()) {
      NavigationHelper.navigate('pages/login/LoginPage'); return;
    }
    NavigationHelper.navigate('pages/forum/NewThreadPage', {
      forumName: this.forumName, forumId: String(this.forumId),
      tabs: JSON.stringify(this.forumTabs.map((t: ForumTab) => {
        const tab: ForumTab = { tabId: t.tabId, tabName: t.tabName, tabType: t.tabType, isGeneralTab: t.isGeneralTab };
        return tab;
      }))
    });
  }

  private showForumMenu(): void {
    AlertDialog.show({
      title: this.forumName,
      message: '',
      autoCancel: true,
      primaryButton: {
        value: '举报',
        action: () => { promptAction.showToast({ message: '已举报', duration: 1500 }); }
      },
      secondaryButton: {
        value: (this.isLiked ? '取消收藏' : '收藏') + ' ' + this.forumName,
        fontColor: '#FF4444',
        action: () => { void this.toggleLike(); }
      }
    });
  }

  private async toggleLike(): Promise<void> {
    if (!AccountManager.getInstance().isLoggedIn()) {
      NavigationHelper.navigate('pages/login/LoginPage'); return;
    }
    try {
      if (this.isLiked) {
        await this.repo.unlikeForum(this.forumId, this.forumName);
        this.isLiked = false;
      } else {
        await this.repo.likeForum(this.forumId, this.forumName);
        this.isLiked = true;
      }
    } catch (e) { console.error('Toggle like failed:', e); }
  }

  private async doSign(): Promise<void> {
    if (!AccountManager.getInstance().isLoggedIn()) {
      NavigationHelper.navigate('pages/login/LoginPage'); return;
    }
    try {
      const result = await this.repo.signForum(this.forumId, this.forumName);
      const errCode = (result as Dict).error_code;
      if (errCode !== undefined && errCode !== null && String(errCode) !== '0' && String(errCode) !== '300000') {
        // Already signed or other error
        console.info('TiebaLite: sign error_code=' + errCode + ' msg=' + (result as Dict).error_msg);
        if (String(errCode) === '300001' || String(errCode) === '300002' || String(errCode) === '160002' || String(errCode) === '2001') {
          this.signedToday = true;
          this.signedForumIds.add(this.forumId);
          promptAction.showToast({ message: '已签到', duration: 1000 });
          this.repo.clearCache();
          void this.loadThreads();
          return;
        }
        promptAction.showToast({ message: String((result as Dict).error_msg || '签到失败'), duration: 1500 });
      } else {
        this.signedToday = true;
        this.signedForumIds.add(this.forumId);
        promptAction.showToast({ message: '签到成功', duration: 1500 });
        this.repo.clearCache();
        void this.loadThreads();
      }
    } catch (e) {
      promptAction.showToast({ message: 'Sign error', duration: 1500 });
    }
  }

  private extractTopThreads(d: Dict, rawData?: Dict): Dict[] {
    const candidates = ['top_thread_list', 'topThreadList', 'top_list', 'topList', 'top_thread', 'topThread'];
    const sources = [d, rawData].filter(Boolean);
    for (const src of sources) {
      for (const key of candidates) {
        const val = (src as Dict)[key];
        if (Array.isArray(val) && (val as Dict[]).length > 0) {
          const raw = val as Dict[];
          return raw.map((t: Dict) => this.normalizeTopThread(t));
        }
      }
      for (const k of Object.keys(src as Dict)) {
        if (k.toLowerCase().includes('top') && Array.isArray((src as Dict)[k]) && ((src as Dict)[k] as Dict[]).length > 0) {
          const raw = (src as Dict)[k] as Dict[];
          return raw.map((t: Dict) => this.normalizeTopThread(t));
        }
      }
    }
    return [];
  }

  private normalizeTopThread(t: Dict): Dict {
    const inner = (t.threadList || t.thread_list) as Dict[];
    const item = (inner && Array.isArray(inner) && inner.length > 0) ? inner[0] as Dict : t;
    if (!getStr(item, 'title', 'threadTitle', 'thread_title')) {
      const fallback = getStr(t, 'title', 'threadTitle', 'thread_title', 'topic_name', 'subject');
      if (fallback) item['title'] = fallback;
    }
    if (!getStr(item, 'id', 'tid', 'threadId', 'thread_id')) {
      const fallback = getStr(t, 'id', 'tid', 'threadId', 'thread_id');
      if (fallback) item['id'] = fallback;
    }
    return item;
  }

  private extractThreads(d: Dict, userMap?: Map<string, Dict>): Dict[] {
    if (!d) return [];
    let threads: Dict[] = [];
    if (d.thread_list && (d.thread_list as Dict[]).length > 0) threads = d.thread_list as Dict[];
    else if (d.thread_info && (d.thread_info as Dict[]).length > 0) threads = d.thread_info as Dict[];
    else if (d.post_list && (d.post_list as Dict[]).length > 0) threads = d.post_list as Dict[];
    else if (Array.isArray(d)) threads = d as Dict[];
    else {
      const tl = d['thread_list'] || d['thread_info'] || d['post_list'];
      if (tl && Array.isArray(tl)) threads = tl as Dict[];
    }
    return threads.map((t: Dict) => {
      if (threads.length > 0 && threads.indexOf(t) === 0) {
        console.info('TiebaLite: first raw thread keys=' + Object.keys(t).join(','));
      }
      const inner = (t.threadList || t.thread_list) as Dict[];
      const item = (inner && Array.isArray(inner) && inner.length > 0) ? inner[0] as Dict : t;
      if (item !== t) {
        if ((item as Dict)['agree'] === undefined && (t as Dict)['agree'] !== undefined)
          (item as Dict)['agree'] = (t as Dict)['agree'];
        if ((item as Dict)['agreeNum'] === undefined && (t as Dict)['agreeNum'] !== undefined)
          (item as Dict)['agreeNum'] = (t as Dict)['agreeNum'];
        if ((item as Dict)['agree_num'] === undefined && (t as Dict)['agree_num'] !== undefined)
          (item as Dict)['agree_num'] = (t as Dict)['agree_num'];
        if ((item as Dict)['media'] === undefined && (t as Dict)['media'] !== undefined)
          (item as Dict)['media'] = (t as Dict)['media'];
        if ((item as Dict)['imageUrls'] === undefined && (t as Dict)['imageUrls'] !== undefined)
          (item as Dict)['imageUrls'] = (t as Dict)['imageUrls'];
        if ((item as Dict)['firstPostContent'] === undefined && (t as Dict)['firstPostContent'] !== undefined)
          (item as Dict)['firstPostContent'] = (t as Dict)['firstPostContent'];
        if ((item as Dict)['first_post_content'] === undefined && (t as Dict)['first_post_content'] !== undefined)
          (item as Dict)['first_post_content'] = (t as Dict)['first_post_content'];
        if ((item as Dict)['lastTimeInt'] === undefined && (t as Dict)['lastTimeInt'] !== undefined)
          (item as Dict)['lastTimeInt'] = (t as Dict)['lastTimeInt'];
        if ((item as Dict)['lastTime'] === undefined && (t as Dict)['lastTime'] !== undefined)
          (item as Dict)['lastTime'] = (t as Dict)['lastTime'];
        if ((item as Dict)['last_time'] === undefined && (t as Dict)['last_time'] !== undefined)
          (item as Dict)['last_time'] = (t as Dict)['last_time'];
        if ((item as Dict)['lastTimeStr'] === undefined && (t as Dict)['lastTimeStr'] !== undefined)
          (item as Dict)['lastTimeStr'] = (t as Dict)['lastTimeStr'];
        if ((item as Dict)['last_time_str'] === undefined && (t as Dict)['last_time_str'] !== undefined)
          (item as Dict)['last_time_str'] = (t as Dict)['last_time_str'];
        if ((item as Dict)['createTime'] === undefined && (t as Dict)['createTime'] !== undefined)
          (item as Dict)['createTime'] = (t as Dict)['createTime'];
        if ((item as Dict)['create_time'] === undefined && (t as Dict)['create_time'] !== undefined)
          (item as Dict)['create_time'] = (t as Dict)['create_time'];
      }
      const author = item.author as Dict | undefined;
      if (author) {
        if (author.name === undefined || author.name === null || String(author.name) === '') {
          const candidate = getStr(author, 'name', 'nameShow', 'name_show', 'nickname', 'userName', 'user_name', 'showName', 'show_name');
          if (candidate) author.name = candidate;
        }
        if (author.portrait === undefined || author.portrait === null || String(author.portrait) === '') {
          const candidate = getStr(author, 'portrait', 'user_portrait', 'avatar', 'avatarUrl');
          if (candidate) author.portrait = candidate;
        }
      }
      if (!author || !author.name || !author.portrait) {
        const authorId = getStr(item, 'author_id', 'authorId', 'userId', 'user_id', 'uid');
        if (authorId && userMap && userMap.has(authorId)) {
          const u = userMap.get(authorId) as Dict;
          if (!item.author) (item as Dict)['author'] = {} as Dict;
          const itemAuthor = item.author as Dict;
          if (!itemAuthor.name) itemAuthor.name = getStr(u, 'name', 'name_show', 'nickname', 'userName', 'user_name', 'showName', 'show_name');
          if (!itemAuthor.portrait) itemAuthor.portrait = getStr(u, 'portrait', 'user_portrait', 'avatar', 'icon');
        }
      }
      if (!item.forumId && !item.forum_id) item.forumId = this.forumId;
      // 提取first_post_content里的media字段
      if ((item as Dict)['media'] === undefined || (item as Dict)['media'] === null || ((item as Dict)['media'] as Dict[]).length === 0) {
        const fpc = (item as Dict)['firstPostContent'] || (item as Dict)['first_post_content'] || (item as Dict)['_abstract'] || [];
        if (Array.isArray(fpc)) {
          const imgs: Dict[] = [];
          for (const ct of fpc as Dict[]) {
            if (Number(ct.type) === 1 || Number(ct.type) === 3) {
              const src = getStr(ct, 'originSrc', 'src', 'origin_src', 'bigPic', 'big_pic', 'smallPic', 'small_pic', 'url');
              if (src) {
                const httpsSrc = src.startsWith('https://') ? src : src.startsWith('http://') ? 'https://' + src.substring(7) : 'https:' + src;
                imgs.push({ src: httpsSrc, width: getNum(ct, 'width', 'originWidth', 'origin_width', 'bigWidth', 'big_width'), height: getNum(ct, 'height', 'originHeight', 'origin_height', 'bigHeight', 'big_height') });
              }
            } else if (Number(ct.type) === 5) {
              const poster = getStr(ct, 'bsrc', 'poster', 'posterUrl', 'cover', 'coverUrl', 'thumbnail', 'pic', 'src');
              if (poster) {
                imgs.push(ct as Dict);
              }
            }
          }
          if (imgs.length > 0) (item as Dict)['media'] = imgs;
        }
      }
      return item;
    });
  }

  private async loadMore(): Promise<void> {
    this.loadingMore = true;
    try {
      const data: Dict = await this.repo.loadFrsPage(this.forumName, this.page, this.sortType, 0, 0);
      const d = (data.data as Dict) || data;
      const ul = d.user_list;
      const userMap: Map<string, Dict> = new Map();
      if (ul && Array.isArray(ul)) {
        for (const u of ul as Dict[]) {
          const uid = getStr(u, 'id', 'user_id', 'uid');
          if (uid) userMap.set(uid, u);
        }
      }
      const more: Dict[] = this.extractThreads(d, userMap);
      if (more.length === 0) { this.hasMore = false; this.loadingMore = false; return; }
      const existingIds = new Set(this.threads.map(t => getStr(t, 'id', 'tid', 'threadId', 'thread_id')));
      const uniqueNew = more.filter(t => !existingIds.has(getStr(t, 'id', 'tid', 'threadId', 'thread_id')));
      if (uniqueNew.length === 0) { this.hasMore = false; this.loadingMore = false; return; }
      this.threads = [...this.threads, ...uniqueNew];
      this.loadingMore = false;
    } catch (e) { this.hasMore = false; this.loadingMore = false; }
  }

  private handleFabScroll(sc: Scroller): void {
    const y = sc.currentOffset().yOffset;
    const delta = y - this.lastFabScrollY;
    this.lastFabScrollY = y;
    if (Math.abs(delta) > 2000 || Math.abs(delta) < 0.5) return;
    if (delta > 5) {
      if (this.fabVisible) {
        animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
          this.fabVisible = false;
          this.showFabMenu = false;
        });
      }
    } else if (delta < -5 && y > 500) {
      if (!this.fabVisible) {
        animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
          this.fabVisible = true;
        });
      }
    }
  }

  private contentTopPad(): number {
    return this.headerCollapsed ? 101 - this.nameRowHeight : 101;
  }

  private handleHeaderScroll(sc: Scroller): void {
    const y = sc.currentOffset().yOffset;
    if (!this.hideOnScroll) return;
    if (sc !== this.lastHeaderScroller) {
      this.lastHeaderScroller = sc;
      this.lastHeaderY = y;
      return;
    }
    const delta = y - this.lastHeaderY;
    this.lastHeaderY = y;
    if (Math.abs(delta) > 2000 || Math.abs(delta) < 0.5) return;
    if (delta > 5 && !this.headerCollapsed) {
      animateTo({ duration: 220, curve: Curve.FastOutSlowIn }, () => {
        this.headerCollapsed = true;
      });
    } else if (delta < -5 && this.headerCollapsed) {
      animateTo({ duration: 220, curve: Curve.FastOutSlowIn }, () => {
        this.headerCollapsed = false;
      });
    } else if (y <= 2 && this.headerCollapsed) {
      animateTo({ duration: 220, curve: Curve.FastOutSlowIn }, () => {
        this.headerCollapsed = false;
      });
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
    if (!this.fabVisible) {
      this.fabLeft = toLeft;
      return;
    }
    const wasVisible = this.fabVisible;
    animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
      this.fabVisible = false;
      this.showFabMenu = false;
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

  @Builder
  FabMenuItems() {
    Column() {
      this.FabMenuRow($r('app.media.ic_edit'), 'New Thread', (): void => { this.showFabMenu = false; this.openNewThread(); })
      this.FabMenuRow($r('app.media.ic_refresh'), 'Refresh', (): void => { this.showFabMenu = false; this.loadThreads(); this.scroller.scrollEdge(Edge.Top); })
      this.FabMenuRow($r('app.media.ic_arrow_up'), 'Scroll Top', (): void => { this.showFabMenu = false; this.scroller.scrollEdge(Edge.Top); })
    }
    .transition(TransitionEffect.opacity(0).combine(TransitionEffect.translate({ y: 20 })))
    .padding({ bottom: 4 })
  }

  @Builder
  FabMenuRow(iconRes: Resource, _label: string, action: () => void) {
    Row() {
      Image(iconRes).width(Math.round(18 * this.fontScale)).height(Math.round(18 * this.fontScale)).fillColor(textPrimary(this.isDark))
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(blendWithBg(this.primaryColor, 0.12, this.isDark, '#1E1E1E'))
    .borderRadius(20)
    .shadow({ radius: 4, color: shadowColor(this.isDark), offsetY: 2 })
    .margin({ bottom: 8 })
    .onClick(() => { action(); })
  }

  @Builder
  FabButton() {
    Stack() {
      Text('+')
        .fontFamily(this.appFontFamily).fontSize(28).fontColor(onPrimaryContainer(this.isDark)).fontWeight(FontWeight.Lighter)
        .rotate({ angle: this.showFabMenu ? 135 : 0 })
        .animation({ duration: 200, curve: Curve.FastOutSlowIn })
    }
    .width(52).height(52).borderRadius(26 * this.fabRadius / 100).backgroundColor(primaryContainer(this.isDark))
    .shadow({ radius: 8, color: shadowColor(this.isDark), offsetY: 4 })
    .onClick(() => { this.showFabMenu = !this.showFabMenu; })
  }

  @Builder
  topSectionContent() {
    ForEach(this.getVisibleItems(), (item: Dict, index: number) => {
      Row() {
        Row() {
          Text(item._isRule ? '吧规' : '置顶')
            .fontFamily(this.appFontFamily).fontSize(Math.round(11 * this.fontScale)).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
        }
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .backgroundColor(item._isRule ? '#FF8800' : this.primaryColor).borderRadius(4)
        Text(getStr(item, 'title', 'threadTitle', 'thread_title', 'topic_name', 'subject')).fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textPrimary(this.isDark))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1).margin({ left: 8 })
      }
      .width('100%').height(40).padding({ left: 14, right: 14 })
      .onClick(() => {
        if (item._isRule) {
          promptAction.showToast({ message: 'Forum rules', duration: 1500 });
        } else {
          NavigationHelper.navigate('pages/thread/ThreadPage', {
            threadId: getStr(item, 'id', 'tid', 'threadId', 'thread_id', 'topic_id'),
            forumId: String(this.forumId),
            forumName: this.forumName
          });
        }
      })
      if (index < this.getVisibleItems().length - 1) {
        Divider().height(0.75).color(pageBg(this.isDark)).margin({ left: 14 })
      }
    })
    if (this.hasMoreItems()) {
      Row() {
        Text(this.topExpanded ? 'Show less' : 'Show more')
          .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textAccent(this.primaryColor, this.isDark))
      }
      .width('100%').height(36).justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.topExpanded = !this.topExpanded;
      })
    }
  }

  getVisibleItems(): Dict[] {
    const maxVisible = 4;
    const combined: Dict[] = [];
    if (this.forumRule && this.ruleTitle) {
      combined.push({ _isRule: true, title: this.ruleTitle } as Dict);
    }
    for (let i = 0; i < this.topThreads.length; i++) {
      combined.push(this.topThreads[i] as Dict);
    }
    if (this.topExpanded) return combined;
    return combined.slice(0, maxVisible);
  }

  hasMoreItems(): boolean {
    let count = this.topThreads.length;
    if (this.forumRule && this.ruleTitle) count++;
    return count > 4;
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
