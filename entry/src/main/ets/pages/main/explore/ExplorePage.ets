import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import window from '@ohos.window';
import display from '@ohos.display';
import { NavigationHelper } from '../../../core/utils/NavigationHelper';
import promptAction from '@ohos.promptAction';
import AccountManager from '../../../core/auth/AccountManager';
import ExploreRepository from '../../../core/repository/ExploreRepository';
import HotTopicRepository from '../../../core/repository/HotTopicRepository';
import SearchRepository from '../../../core/repository/SearchRepository';
import ThreadCard from '../../../components/ThreadCard';
import LoadingState from '../../../components/LoadingState';
import ErrorState from '../../../components/ErrorState';
import GearLoading from '../../../components/GearLoading';
import GearCycle from '../../../components/GearCycle';
import PullToRefresh from '../../../components/PullToRefresh';
import PbPageRepository from '../../../core/repository/PbPageRepository';
import BlockRepository from '../../../core/repository/BlockRepository';
import PreferencesManager from '../../../core/storage/PreferencesManager';
import { Dict } from '../../../core/types/Dict';
import { GripDetector } from '../../../core/utils/GripDetector';
import { getStr, getNum, getStrObj, blendWithWhite, darkenColor, blendWithBg, textAccent, pageBg, cardBg, textPrimary, 
textSecondary, textTertiary, dividerColor, shadowColor, withAlpha, primaryContainer, onPrimaryContainer } from '../../../core/utils/DataHelper';

const CACHE_TTL = 30 * 60 * 1000;

interface FollowingCache {
  threads: Dict[];
  pageTag: string;
  requestUnix: string;
  hasMore: boolean;
}
interface RecommendedCache {
  threads: Dict[];
  hasMore: boolean;
}
interface HotCache {
  threads: Dict[];
  tabs: Dict[];
  topics: Dict[];
}
interface ExplorePageCache {
  following: FollowingCache;
  recommended: RecommendedCache;
  hot: HotCache;
  cachedAt: number;
}

let explorePageCache: ExplorePageCache | null = null;

@Component
export default struct ExplorePage {
  @StorageLink('primaryColor') @Watch('onColorChanged') primaryColor: string = '#4477E0';
  @StorageLink('showSwiperDots') showSwiperDots: boolean = true;
  @StorageLink('gripSide') @Watch('onGripSideChanged') gripSide: number = 0;
  @StorageLink('fabRadius') fabRadius: number = 60;
  reduceEffects: boolean = false;
  @StorageLink('fontScale') fontScale: number = 1.0;
  @StorageLink('cardStyle') cardStyle: number = 0;
  @StorageLink('headerAlpha') headerAlpha: number = 25;
  @StorageLink('headerTint') headerTint: number = 8;
  @StorageLink('isDarkTheme') @Watch('onColorChanged') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @StorageLink('searchBoxRound') searchBoxRound: number = 100;
  @StorageProp('hideOnScroll') hideOnScroll: boolean = true;
  @State bgColor: string = pageBg(AppStorage.Get<boolean>('isDarkTheme') ?? false);
  @State topInset: number = 24;
  @State refreshBanner: string = '';
  @State refreshBannerOpacity: number = 0;
  private refreshBannerTimer: number = -1;
  @State loadingMoreGearVisible: boolean = false;
  @State loadingMoreGearOffset: number = 60;
  @State loadingMoreGearOpacity: number = 0;
  @Prop @Watch('onActiveChanged') active: boolean = true;
  @State selectedTab: number = 1;
  @State tabProgress: number = 1;
  @State hotThreads: Dict[] = [];
  @State followingThreads: Dict[] = [];
  @State recommendedThreads: Dict[] = [];
  @State hotTopics: Dict[] = [];
  @State hotTabs: Dict[] = [];
  @State selectedHotTabIndex: number = 0;
  @State loading: boolean = true;
  @State error: string = '';
  @State followingPage: number = 1;
  @State recommendedPage: number = 1;
  @State hotPage: number = 1;
  @State hotTabPage: number = 1;
  @State followingHasMore: boolean = true;
  @State recommendedHasMore: boolean = true;
  @State hotHasMore: boolean = true;
  @State @Watch('onRefresh0Change') isRefreshing0: boolean = false;
  @State @Watch('onRefresh1Change') isRefreshing1: boolean = false;
  @State @Watch('onRefresh2Change') isRefreshing2: boolean = false;
  @State refreshing: boolean = false;
  @State loadingMore: boolean = false;
  @State pullDistance: number = 0;
  @State pullRefreshing: boolean = false;
  @State followingPageTag: string = '';
  @State followingRequestUnix: string = '0';
  @State tabIndicatorOffset: number = 0;
  @State indicatorWidth: number = 20;
  @State tabTextWidths: number[] = [];
  @State tabBarWidth: number = 0;
  @State fabVisible: boolean = false;
  @State fabLeft: boolean = false;
  @State showFabMenu: boolean = false;
  private fabTimer: number = -1;
  @State showHotTabMenu: boolean = false;
  @State searchBarVisible: boolean = true;
  private lastScrollYByTab: number[] = [0, 0, 0];
  private scrollers: Scroller[] = [new Scroller(), new Scroller(), new Scroller()];
  private screenWidth: number = 0;

  onColorChanged(): void {
    this.bgColor = pageBg(this.isDark);
  }

  onActiveChanged(): void {
    this.reduceEffects = AppStorage.get<boolean>('reduceEffects') === true;
    if (!this.active) {
      this.showHotTabMenu = false;
      this.showFabMenu = false;
    }
  }

  private tabNames: string[] = ['关注', '推荐', '热门'];
  private allHotTabNames: string[] = ['总榜', '体育', '数码', '游戏', '小说', '动漫', '影视', '明星', '音乐', '汽车', '美食', '萌宠', '搞笑', '历史', '军事', '财经'];
  private defaultHotTabConfig: string[] = ['体育', '数码', '游戏', '小说'];
  @State hotTabConfig: string[] = [];
  private repo: ExploreRepository = ExploreRepository.getInstance();
  private topicRepo: HotTopicRepository = HotTopicRepository.getInstance();
  private searchRepo: SearchRepository = SearchRepository.getInstance();

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
      console.warn('TiebaLite: ExplorePage initTopInset failed ' + JSON.stringify(e));
    }
  }

  aboutToAppear(): void {
    const t0 = new Date().getTime();
    console.info('TiebaLite: [E1] ExplorePage aboutToAppear start t=' + t0);
    this.initTopInset();
    this.onGripSideChanged();
    try {
      const params = router.getParams() as Record<string, Object>;
      if (params && params.initialTab !== undefined) {
        this.selectedTab = Number(params.initialTab);
      }
    } catch (e) {}
    this.screenWidth = 360;
    void this.loadHotTabConfig();
    const initialDone = AppStorage.Get<boolean>('exploreInitialLoadDone') ?? false;
    if (!initialDone) {
      this.loadInitialData();
      AppStorage.SetOrCreate('exploreInitialLoadDone', true);
    } else if (explorePageCache && (Date.now() - explorePageCache.cachedAt) < CACHE_TTL) {
      this.restoreFromCache();
    } else {
      this.loadInitialData();
    }
    AccountManager.getInstance().onAccountChange((): void => {
      explorePageCache = null;
      this.loadInitialData();
    });
    setTimeout(() => { this.updateIndicatorOffset(); }, 0);
    console.info('TiebaLite: [E2] ExplorePage aboutToAppear end t=' + (new Date().getTime() - t0) + 'ms');
  }

  onPageShow(): void {
    const v = AppStorage.get<number>('pageShowTick') || 0;
    AppStorage.SetOrCreate('pageShowTick', v + 1);
  }

  onPageHide(): void {
    const v = AppStorage.get<number>('pageHideTick') || 0;
    AppStorage.SetOrCreate('pageHideTick', v + 1);
  }

  async loadInitialData(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const results = await Promise.all([
        this.loadPersonalizedWithFallback(1).catch(() => null),
        this.loadFollowingWithFallback().catch(() => null),
        this.repo.loadHotThreads('all').catch(() => null),
        this.topicRepo.loadTopicList().catch(() => null)
      ]);
      const recomResult = results[0];
      const followResult = results[1];
      const hotResult = results[2];
      const topicsResult = results[3];

      if (recomResult) {
        this.recommendedThreads = this.extractThreads(recomResult);
        console.info('TiebaLite: recommended result keys=' + Object.keys(recomResult).join(',') + ' threads=' + this.recommendedThreads.length);
      }
      if (followResult) {
        const fd = (followResult.data as Dict) || followResult;
        this.followingPageTag = getStr(fd, 'pageTag', 'page_tag') || '';
        this.followingRequestUnix = String(getNum(fd, 'requestUnix', 'request_unix') || 0);
        const fhm = fd['hasMore'] ?? fd['has_more'];
        this.followingHasMore = fhm === undefined || fhm === null ? true : Number(fhm) !== 0;
        this.followingThreads = this.extractThreads(followResult);
        console.info('TiebaLite: following keys=' + Object.keys(followResult).join(',') + ' threads=' + this.followingThreads.length + ' pageTag=' + this.followingPageTag + ' requestUnix=' + this.followingRequestUnix + ' hasMore=' + this.followingHasMore);
      }
      if (hotResult) {
        this.hotThreads = this.extractThreads(hotResult);
        this.buildHotTabs();
        this.hotTopics = this.extractTopics(hotResult);
        console.info('TiebaLite: hot threads=' + this.hotThreads.length + ' tabs=' + this.hotTabs.length + ' topics=' + this.hotTopics.length);
      }
      if (topicsResult && this.hotTopics.length === 0) {
        const extraTopics = this.extractTopics(topicsResult);
        if (extraTopics.length > 0) this.hotTopics = extraTopics;
      }
      this.saveToCache();
    } finally {
      this.loading = false;
    }
  }

  private restoreFromCache(): void {
    if (!explorePageCache) return;
    this.followingThreads = explorePageCache.following.threads;
    this.followingPageTag = explorePageCache.following.pageTag;
    this.followingRequestUnix = explorePageCache.following.requestUnix;
    this.followingHasMore = explorePageCache.following.hasMore;
    this.recommendedThreads = explorePageCache.recommended.threads;
    this.recommendedHasMore = explorePageCache.recommended.hasMore;
    this.hotThreads = explorePageCache.hot.threads;
    this.buildHotTabs();
    this.hotTopics = explorePageCache.hot.topics;
    this.loading = false;
  }

  private saveToCache(): void {
    explorePageCache = {
      following: {
        threads: this.followingThreads,
        pageTag: this.followingPageTag,
        requestUnix: this.followingRequestUnix,
        hasMore: this.followingHasMore
      } as FollowingCache,
      recommended: {
        threads: this.recommendedThreads,
        hasMore: this.recommendedHasMore
      } as RecommendedCache,
      hot: {
        threads: this.hotThreads,
        tabs: this.hotTabs,
        topics: this.hotTopics
      } as HotCache,
      cachedAt: Date.now()
    } as ExplorePageCache;
  }

  private effectiveHotTabConfig(): string[] {
    return this.hotTabConfig.length > 0 ? this.hotTabConfig : this.defaultHotTabConfig;
  }

  private buildHotTabs(): void {
    const tabs: Dict[] = [{ tabName: '总榜', tabCode: 'all' } as Dict];
    const cfg = this.effectiveHotTabConfig();
    for (const name of this.allHotTabNames) {
      if (name === '总榜') continue;
      if (cfg.indexOf(name) >= 0) {
        tabs.push({ tabName: name, tabCode: name } as Dict);
      }
    }
    this.hotTabs = tabs;
  }

  private getHotTabName(index: number): string {
    const tab = this.hotTabs[index] as Dict | undefined;
    return tab ? getStr(tab, 'tabName', 'name') || '' : '';
  }

  private isHotTabEnabled(name: string): boolean {
    return this.hotTabConfig.indexOf(name) >= 0;
  }

  private async loadHotTabConfig(): Promise<void> {
    try {
      const saved = await PreferencesManager.getInstance().getString('hot_tab_config', '');
      if (saved) {
        const arr = JSON.parse(saved) as string[];
        if (Array.isArray(arr)) {
          this.hotTabConfig = arr.filter((n: string) => typeof n === 'string' && n.length > 0 && n !== '总榜');
        }
      }
    } catch (_e) {}
    this.buildHotTabs();
  }

  private toggleHotTab(name: string): void {
    if (name === '总榜') return;
    const idx = this.hotTabConfig.indexOf(name);
    if (idx >= 0) {
      this.hotTabConfig = this.hotTabConfig.filter((n: string) => n !== name);
    } else {
      this.hotTabConfig = [...this.hotTabConfig, name];
    }
    PreferencesManager.getInstance().putString('hot_tab_config', JSON.stringify(this.hotTabConfig)).catch(() => {});
    const curName = this.getHotTabName(this.selectedHotTabIndex);
    this.buildHotTabs();
    const newIdx = this.hotTabs.findIndex((t: Dict) => getStr(t, 'tabName', 'name') === curName);
    this.selectedHotTabIndex = newIdx > 0 ? newIdx : 0;
    if (newIdx <= 0 && curName !== '总榜') {
      void this.loadHotTab(0);
    }
  }

  private async loadPersonalizedWithFallback(page: number): Promise<Dict | null> {
    const isLoggedIn = AccountManager.getInstance().isLoggedIn();
    if (!isLoggedIn) {
      console.info('TiebaLite: not logged in, cannot load personalized');
      return null;
    }
    const attempts = [
      () => this.repo.loadPersonalized(page),
      () => this.repo.loadPersonalizedProto(page)
    ];
    for (const attempt of attempts) {
      try {
        const data: Dict = await attempt();
        const d = (data.data as Dict) || data;
        console.info('TiebaLite: loadPersonalized attempt response keys=' + Object.keys(d).join(','));
        const threads = d.thread_list || d.threadList || d.thread_info || d.threadInfo || d.feed || d.data_list || d.dataList || d.thread || d.list || d.items || d.post_list || d.postList || [];
        if (Array.isArray(threads) && threads.length > 0) {
          console.info('TiebaLite: loadPersonalizedWithFallback success, threads=' + threads.length);
          return data;
        }
        console.info('TiebaLite: loadPersonalizedWithFallback empty, attempt keys=' + Object.keys(d).join(','));
      } catch (e) {
        console.info('TiebaLite: loadPersonalizedWithFallback attempt failed: ' + String(e));
      }
    }
    return null;
  }

  switchTab(index: number): void {
    if (this.selectedTab === index) return;
    this.resetFabScrollState();
    animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
      this.selectedTab = index;
      this.tabProgress = index;
      this.updateIndicatorOffset();
    });
    if (index === 0 && this.followingThreads.length === 0) {
      this.followingPage = 1;
      this.loadFollowingTab();
    } else if (index === 1 && this.recommendedThreads.length === 0) {
      this.recommendedPage = 1;
      this.loadRecommendedTab();
    } else if (index === 2 && (this.hotThreads.length === 0 || this.hotTabs.length === 0)) {
      this.hotPage = 1;
      this.loadHotTab(0);
    }
  }

  onSwiperChange(index: number): void {
    if (this.selectedTab === index) return;
    this.resetFabScrollState();
    this.selectedTab = index;
    if (index === 0 && this.followingThreads.length === 0) {
      this.followingPage = 1;
      this.followingHasMore = true;
      this.loadFollowingTab();
    } else if (index === 1 && this.recommendedThreads.length === 0) {
      this.recommendedPage = 1;
      this.recommendedHasMore = true;
      this.loadRecommendedTab();
    } else if (index === 2 && (this.hotThreads.length === 0 || this.hotTabs.length === 0)) {
      this.hotPage = 1;
      this.hotHasMore = true;
      this.loadHotTab(0);
    }
  }

  switchHotTab(tabIndex: number): void {
    this.selectedHotTabIndex = tabIndex;
    this.loadHotTab(tabIndex);
  }

  async loadHotTab(tabIndex: number): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      if (tabIndex === 0) {
        const data: Dict = await this.repo.loadHotThreads('all');
        this.hotThreads = this.extractThreads(data);
        const topics = this.extractTopics(data);
        if (topics.length > 0) this.hotTopics = topics;
      } else {
        const tabName = this.getHotTabName(tabIndex);
        const searchData: Dict = await this.searchRepo.searchThread(tabName, 1, 2);
        this.hotThreads = this.extractThreads(searchData);
        this.hotTabPage = 1;
        this.hotHasMore = true;
      }
      console.info('TiebaLite: hotTab loaded tabIndex=' + tabIndex + ' threads=' + this.hotThreads.length);
      this.saveToCache();
    } catch (e) {
      this.error = '加载失败';
    } finally {
      this.loading = false;
    }
  }

  private async loadFollowingWithFallback(): Promise<Dict | null> {
    if (!AccountManager.getInstance().isLoggedIn()) {
      return this.loadPersonalizedWithFallback(1);
    }
    try {
      console.info('TiebaLite: loadFollowingWithFallback trying userLikeFlow (protobuf)');
      const data: Dict = await this.repo.loadUserLikeFlow('', 1);
      const d = (data.data as Dict) || data;
      const threads = this.extractThreads(data);
      console.info('TiebaLite: userLikeFlow response keys=' + Object.keys(data).join(',') + ' dataKeys=' + Object.keys(d).join(',') + ' threads=' + threads.length);
      if (Array.isArray(threads) && threads.length > 0) {
        return data;
      }
      console.info('TiebaLite: userLikeFlow returned empty threads, fallback to personalized');
    } catch (e) {
      console.info('TiebaLite: userLikeFlow failed: ' + String(e) + ', fallback to personalized');
    }
    return this.loadPersonalizedWithFallback(1);
  }

  async loadFollowingTab(): Promise<void> {
    this.loading = true;
    this.error = '';
    this.followingPageTag = '';
    this.followingRequestUnix = '0';
    this.followingHasMore = true;
    try {
      const data: Dict | null = await this.loadFollowingWithFallback();
      if (data) {
        const d = (data.data as Dict) || data;
        this.followingPageTag = getStr(d, 'pageTag', 'page_tag') || '';
        this.followingRequestUnix = String(getNum(d, 'requestUnix', 'request_unix') || 0);
        const fhm = d['hasMore'] ?? d['has_more'];
        this.followingHasMore = fhm === undefined || fhm === null ? true : Number(fhm) !== 0;
        this.followingThreads = this.extractThreads(data);
        console.info('TiebaLite: followingTab loaded threads=' + this.followingThreads.length + ' pageTag=' + this.followingPageTag + ' requestUnix=' + this.followingRequestUnix + ' hasMore=' + this.followingHasMore);
        this.saveToCache();
      }
    } catch (e) {
      this.error = '加载失败';
    } finally {
      this.loading = false;
    }
  }

  async loadRecommendedTab(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const data: Dict | null = await this.loadPersonalizedWithFallback(1);
      if (data) this.recommendedThreads = this.extractThreads(data);
      console.info('TiebaLite: recommendedTab loaded threads=' + this.recommendedThreads.length);
      this.saveToCache();
    } catch (e) {
      this.error = '加载失败，点击重试';
    } finally {
      this.loading = false;
    }
  }

  private onRefresh0Change(): void {
    if (this.isRefreshing0) {
      this.pullRefreshing = true;
      void this.doRefresh(0);
    } else {
      this.pullRefreshing = false;
      this.pullDistance = 0;
    }
  }
  private onRefresh1Change(): void {
    if (this.isRefreshing1) {
      this.pullRefreshing = true;
      void this.doRefresh(1);
    } else {
      this.pullRefreshing = false;
      this.pullDistance = 0;
    }
  }
  private onRefresh2Change(): void {
    if (this.isRefreshing2) {
      this.pullRefreshing = true;
      void this.doRefresh(2);
    } else {
      this.pullRefreshing = false;
      this.pullDistance = 0;
    }
  }

  private showRefreshBanner(msg: string): void {
    if (this.refreshBannerTimer !== -1) {
      clearTimeout(this.refreshBannerTimer);
      this.refreshBannerTimer = -1;
    }
    this.refreshBanner = msg;
    animateTo({ duration: 200, curve: Curve.EaseOut }, (): void => {
      this.refreshBannerOpacity = 1;
    });
    this.refreshBannerTimer = setTimeout(() => {
      this.refreshBannerTimer = -1;
      animateTo({ duration: 250, curve: Curve.EaseIn }, (): void => {
        this.refreshBannerOpacity = 0;
      });
      setTimeout(() => {
        if (this.refreshBannerOpacity <= 0) {
          this.refreshBanner = '';
        }
      }, 280);
    }, 2000);
  }

  async doRefresh(tabIndex: number): Promise<void> {
    this.refreshing = true;
    try {
      if (tabIndex === 0) {
        this.followingPage = 1;
        this.followingPageTag = '';
        this.followingRequestUnix = '0';
        this.followingHasMore = true;
        const data: Dict | null = await this.loadFollowingWithFallback();
        if (data) {
          const d = (data.data as Dict) || data;
          this.followingPageTag = getStr(d, 'pageTag', 'page_tag') || '';
          this.followingRequestUnix = String(getNum(d, 'requestUnix', 'request_unix') || 0);
          this.followingHasMore = getNum(d, 'hasMore', 'has_more') !== 0;
          const newThreads = this.extractThreads(data);
          const existingIds = new Set(this.followingThreads.map(t => getStr(t, 'id', 'tid', 'threadId', 'thread_id')));
          const uniqueNew = newThreads.filter(t => !existingIds.has(getStr(t, 'id', 'tid', 'threadId', 'thread_id'))).slice(0, 16);
          if (uniqueNew.length > 0) {
            this.followingThreads = [...uniqueNew, ...this.followingThreads];
            this.showRefreshBanner('刷新了 ' + uniqueNew.length + ' 个帖子');
          } else {
            this.showRefreshBanner('暂无新帖子');
          }
        }
      } else if (tabIndex === 1) {
        this.recommendedPage = 1;
        this.recommendedHasMore = true;
        const data: Dict | null = await this.loadPersonalizedWithFallback(1);
        if (data) {
          const newThreads = this.extractThreads(data);
          const existingIds = new Set(this.recommendedThreads.map(t => getStr(t, 'id', 'tid', 'threadId', 'thread_id')));
          const uniqueNew = newThreads.filter(t => !existingIds.has(getStr(t, 'id', 'tid', 'threadId', 'thread_id'))).slice(0, 16);
          if (uniqueNew.length > 0) {
            this.recommendedThreads = [...uniqueNew, ...this.recommendedThreads];
            this.showRefreshBanner('刷新了 ' + uniqueNew.length + ' 个帖子');
          } else {
            this.showRefreshBanner('暂无新帖子');
          }
        }
      } else {
        this.hotPage = 1;
        if (this.selectedHotTabIndex === 0) {
          const data: Dict = await this.repo.loadHotThreads('all');
          this.hotThreads = this.extractThreads(data);
          const topics = this.extractTopics(data);
          if (topics.length > 0) this.hotTopics = topics;
        } else {
          const tabName = this.getHotTabName(this.selectedHotTabIndex);
          const searchData: Dict = await this.searchRepo.searchThread(tabName, 1, 2);
          this.hotThreads = this.extractThreads(searchData);
          this.hotTabPage = 1;
          this.hotHasMore = true;
        }
      }
      this.saveToCache();
    } catch (e) {
      console.info('TiebaLite: refresh failed: ' + String(e));
    } finally {
      setTimeout(() => {
        this.refreshing = false;
        if (tabIndex === 0) this.isRefreshing0 = false;
        else if (tabIndex === 1) this.isRefreshing1 = false;
        else this.isRefreshing2 = false;
      }, 300);
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

  private onTabScroll(scrollIdx: number): void {
    const y = this.scrollers[scrollIdx].currentOffset().yOffset;
    const delta = y - this.lastScrollYByTab[scrollIdx];
    this.lastScrollYByTab[scrollIdx] = y;
    if (Math.abs(delta) > 2000 || Math.abs(delta) < 0.5) return;
    if (this.hideOnScroll) {
      if (delta > 5) {
        if (this.searchBarVisible) {
          this.searchBarVisible = false;
        }
      } else if (delta < -5) {
        if (this.searchBarVisible === false) {
          this.searchBarVisible = true;
        }
      }
    }
    if (delta > 5) {
      if (this.fabVisible) {
        animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
          this.fabVisible = false;
          this.showFabMenu = false;
        });
      }
    } else if (delta < -5) {
      if (y > 500 && this.fabVisible === false) {
        animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
          this.fabVisible = true;
        });
      }
    }
  }

  private resetFabScrollState(): void {
    this.lastScrollYByTab[this.selectedTab] = this.scrollers[this.selectedTab].currentOffset().yOffset;
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

  private fabRefresh(): void {
    this.showFabMenu = false;
    void this.doRefresh(this.selectedTab);
    this.scrollers[this.selectedTab].scrollTo({ xOffset: 0, yOffset: 0, animation: { duration: 300, curve: Curve.FastOutSlowIn } });
  }

  private fabScrollToTop(): void {
    this.showFabMenu = false;
    this.scrollers[this.selectedTab].scrollTo({ xOffset: 0, yOffset: 0, animation: { duration: 300, curve: Curve.FastOutSlowIn } });
  }

  @Builder
  exploreTabContent(tab: number) {
    Scroll(this.scrollers[tab]) {
      Column() {
        Blank().height(90)
        if (tab === 0) {
          if (this.loading && !this.refreshing) {
            LoadingState({ message: '加载中...' })
          } else if (this.error.length > 0 && !this.refreshing) {
            ErrorState({ message: this.error, onRetryAction: (): void => this.switchTab(this.selectedTab) })
          } else if (!AccountManager.getInstance().isLoggedIn()) {
            Text('请先登录').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark)).width('100%').textAlign(TextAlign.Center).margin({ top: 80 })
              .onClick(() => { NavigationHelper.navigate('pages/login/LoginPage'); })
          } else if (this.followingThreads.length === 0) {
            Text('暂无关注内容\n关注用户后这里会显示帖子').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark)).width('100%').textAlign(TextAlign.Center).margin({ top: 80 })
          } else {
            ForEach(this.followingThreads, (thread: Dict, idx: number) => {
              ThreadCard({
                thread: thread,
                onCardClick: (): void => {
                  NavigationHelper.navigate('pages/thread/ThreadPage', {
                    threadId: getStr(thread, 'id', 'tid', 'threadId', 'thread_id'),
                    forumId: getStr(thread, 'forumId', 'forum_id'),
                    forumName: this.getForumName(thread)
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
              }).margin({ left: 12, right: 12, top: 6, bottom: 6 })
            })
            if (this.followingHasMore) {
              Row() {
                if (this.loadingMore && this.reduceEffects) {
                  GearLoading({ gearSize: 24, color: darkenColor(this.primaryColor, 0.2), text: '加载更多...' })
                } else if (this.loadingMore) {
                } else {
                  Text('加载更多').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor('#4477E0').width('100%').textAlign(TextAlign.Center).padding(16).onClick(() => { void this.loadMore(); })
                }
              }
              .width('100%').justifyContent(FlexAlign.Center).padding({ bottom: 16 })
            }
          }
        } else if (tab === 1) {
          if (this.loading && !this.refreshing) {
            LoadingState({ message: '加载中...' })
          } else if (this.error.length > 0 && !this.refreshing) {
            ErrorState({ message: this.error, onRetryAction: (): void => this.switchTab(this.selectedTab) })
          } else if (!AccountManager.getInstance().isLoggedIn()) {
            Text('请先登录\n登录后即可获取个性化推荐').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark)).width('100%').textAlign(TextAlign.Center).margin({ top: 80 })
              .onClick(() => { NavigationHelper.navigate('pages/login/LoginPage'); })
          } else if (this.recommendedThreads.length === 0) {
            Text('暂无推荐内容\n试试切换到其他标签页').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark)).width('100%').textAlign(TextAlign.Center).margin({ top: 80 })
          } else {
            ForEach(this.recommendedThreads, (thread: Dict, idx: number) => {
              ThreadCard({
                thread: thread,
                onCardClick: (): void => {
                  NavigationHelper.navigate('pages/thread/ThreadPage', {
                    threadId: getStr(thread, 'id', 'tid', 'threadId', 'thread_id'),
                    forumId: getStr(thread, 'forumId', 'forum_id'),
                    forumName: this.getForumName(thread)
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
              }).margin({ left: 12, right: 12, top: 6, bottom: 6 })
            })
          }
        } else {
          if (this.loading && !this.refreshing) {
            LoadingState({ message: '加载中...' })
          } else if (this.error.length > 0 && !this.refreshing) {
            ErrorState({ message: this.error, onRetryAction: (): void => this.switchTab(this.selectedTab) })
          } else {
            if (this.hotTopics.length > 0) {
              Column() {
                Row() {
                  Row() {
                    Image($r('app.media.ic_hot')).width(Math.round(16 * this.fontScale)).height(Math.round(16 * this.fontScale)).fillColor('#FF6B35')
                    Text('热门话题').fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark)).margin({ left: 6 })
                  }
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 }).backgroundColor('#FFF0E8').borderRadius(4)
                  Blank()
                }
                .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 4 })

                Column() {
                  ForEach(this.chunkTopics(this.hotTopics.slice(0, 6)), (pair: Dict[], rowIdx: number) => {
                    Row() {
                      ForEach(pair, (topic: Dict, colIdx: number) => {
                        this.TopicItem(topic, rowIdx * 2 + colIdx)
                      })
                    }
                    .width('100%').height(44).padding({ left: 16, right: 16 })
                  })
                  Row() {
                    if (this.hotTopics.length > 6) {
                      this.TopicItem(this.hotTopics[6], 6)
                    } else {
                      Row().layoutWeight(1).height(36)
                    }
                    Row() {
                      Text('查看更多话题 >>').fontFamily(this.appFontFamily).fontSize(Math.round(13 * this.fontScale)).fontColor(textAccent(this.primaryColor, this.isDark)).fontWeight(FontWeight.Medium)
                    }
                    .layoutWeight(1).height(36).justifyContent(FlexAlign.Center)
                    .onClick(() => { NavigationHelper.navigate('pages/hottopic/HotTopicListPage'); })
                  }
                  .width('100%').height(44).padding({ left: 16, right: 16 })
                }
                .width('100%').backgroundColor(this.bgColor)
              }
              .width('100%').margin({ bottom: 4 })

              Divider().height(9).color(blendWithBg(this.primaryColor, 0.06, this.isDark, '#1E1E1E')).width('100%')
            }

            if (this.hotTabs.length > 0) {
              Row() {
                Scroll() {
                  Row() {
                    ForEach(this.hotTabs, (tab: Dict, idx: number) => {
                      Text(getStr(tab, 'tabName', 'name') || 'Hot')
                        .fontFamily(this.appFontFamily).fontSize(Math.round(13 * this.fontScale))
                        .fontColor(this.selectedHotTabIndex === idx ? '#FFFFFF' : textAccent(this.primaryColor, this.isDark))
                        .height(32)
                        .lineHeight(32)
                        .halfLeading(true)
                        .textAlign(TextAlign.Center)
                        .padding({ left: 14, right: 14 })
                        .backgroundColor(this.selectedHotTabIndex === idx ? textAccent(this.primaryColor, this.isDark) : '#EEF2FF')
                        .borderRadius(16).margin({ right: 8 })
                        .onClick(() => { this.switchHotTab(idx); })
                    })
                  }
                  .padding({ left: 16, right: 8, top: 6, bottom: 6 })
                }
                .scrollBar(BarState.Off)
                .scrollable(ScrollDirection.Horizontal).layoutWeight(1).height(44)
                Column() {
                  Image($r('app.media.ic_add')).width(18).height(18).fillColor(textAccent(this.primaryColor, this.isDark))
                }
                .width(32).height(44).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
                .onClick(() => { this.showHotTabMenu = true; })
              }
              .width('100%').height(44).backgroundColor(blendWithBg(this.primaryColor, 0.08, this.isDark, '#1E1E1E'))
            }

            if (this.hotThreads.length === 0) {
              Text('暂无热门内容').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark)).width('100%').textAlign(TextAlign.Center).margin({ top: 40 })
            } else {
              ForEach(this.hotThreads, (thread: Dict, idx: number) => {
                ThreadCard({
                  thread: thread,
                  hotRank: idx,
                  onCardClick: (): void => {
                    NavigationHelper.navigate('pages/thread/ThreadPage', {
                      threadId: getStr(thread, 'id', 'tid', 'threadId', 'thread_id'),
                      forumId: getStr(thread, 'forumId', 'forum_id'),
                      forumName: this.getForumName(thread)
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
                }).margin({ left: 12, right: 12, top: 6, bottom: 6 })
              })
            }
          }
        }
      }
      .width('100%').padding({ bottom: 66 })
    }
    .scrollBar(BarState.Off)
    .width('100%').layoutWeight(1)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor(this.bgColor)
    .edgeEffect(EdgeEffect.None)
    .onReachEnd(() => {
      if (tab === 0) {
        if (this.followingHasMore && !this.loading && !this.refreshing && !this.loadingMore) { this.loadMore(); }
      } else if (tab === 1) {
        if (this.recommendedHasMore && !this.loading && !this.refreshing && !this.loadingMore) { this.recommendedPage++; this.loadMore(); }
      } else {
        if (this.hotHasMore && !this.loading && !this.refreshing && !this.loadingMore) {
          if (this.selectedHotTabIndex > 0) { this.hotTabPage++; } else { this.hotPage++; }
          this.loadMore();
        }
      }
    })
    .onDidScroll(() => { this.onTabScroll(tab); })
  }

  build() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor(this.bgColor)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      Column() {
        Column() {
          Row() {
            Image($r('app.media.ic_search')).width(Math.round(16 * this.fontScale)).height(Math.round(16 * this.fontScale)).fillColor(textTertiary(this.isDark)).margin({ left: 16 })
            Text('搜索贴吧、帖子、用户').fontFamily(this.appFontFamily).fontSize(14 * this.fontScale).fontColor(textTertiary(this.isDark))
            Blank()
          }
          .width('93%').height(this.searchBarVisible ? 44 : 0)
          .clip(true)
          .borderRadius(Math.max(0, Math.round(22 * this.searchBoxRound / 100)))
          .backgroundColor(blendWithBg(this.primaryColor, 0.15, this.isDark, '#1E1E1E'))
          .border({ width: 1, color: dividerColor(this.isDark) })
          .shadow({ radius: 2, color: shadowColor(this.isDark), offsetY: 1 })
          .margin({ top: this.searchBarVisible ? 8 : 0, bottom: this.searchBarVisible ? 4 : 0 })
          .onClick(() => { NavigationHelper.navigate('pages/search/SearchPage'); })
          .translate({ y: this.searchBarVisible ? 0 : -60 })
          .opacity(this.searchBarVisible ? 1 : 0)
          .animation({ duration: 250, curve: Curve.FastOutSlowIn })

          Stack() {
            Row() {
              ForEach(this.tabNames, (name: string, index: number) => {
                Column() {
                  Text(name).fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale))
                    .fontColor(this.selectedTab === index ? textAccent(this.primaryColor, this.isDark) : textSecondary(this.isDark))
                    .fontWeight(this.selectedTab === index ? FontWeight.Bold : FontWeight.Regular)
                    .padding({ bottom: 8 })
                    .onAreaChange((_old: Area, newArea: Area): void => {
                      const w = newArea.width as number;
                      if (w > 0 && Math.abs(w - (this.tabTextWidths[index] || 0)) > 0.5) {
                        this.tabTextWidths[index] = w;
                      }
                    })
                }
                .layoutWeight(1).padding({ top: 8 })
                .onClick(() => { this.switchTab(index); })
              })
            }
            .width('100%').padding({ left: 16, right: 16 })


          Column()
            .width(this.indicatorWidth).height(3).backgroundColor(this.primaryColor).borderRadius(2)
            .position({ left: this.tabIndicatorOffset, bottom: 0 })
          }
          .width('100%')
          .onAreaChange((_old: Area, newArea: Area) => {
            const w = newArea.width as number;
            if (w > 0 && Math.abs(w - this.tabBarWidth) > 0.5) {
              this.tabBarWidth = w - 32;
              this.updateIndicatorOffset();
            }
          })
        }
        .width('100%').backgroundColor(this.cardStyle === 1 ? withAlpha((this.cardStyle === 1 ? darkenColor(this.bgColor, this.headerTint / 100) : this.bgColor), 1 - this.headerAlpha / 100) : withAlpha(this.bgColor, 1 - this.headerAlpha / 100))
        .backdropBlur(60)
        .border({ width: { bottom: 1 }, color: blendWithBg(this.primaryColor, 0.15, this.isDark, '#1E1E1E') })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
        .position({ x: 0, y: 0 })
        .zIndex(2)

        Swiper() {
          if (this.reduceEffects) {
            PullToRefresh({
              reduceEffects: true,
              scroller: this.scrollers[0],
              iconTopOffset: 100,
              isRefreshing: this.isRefreshing0,
              onRefresh: (): void => { this.isRefreshing0 = true; },
              onTimeout: (): void => { this.isRefreshing0 = false; }
            }) {
              this.exploreTabContent(0)
            }
          } else {
            PullToRefresh({
              scroller: this.scrollers[0],
              iconTopOffset: 100,
              isRefreshing: this.isRefreshing0,
              onRefresh: (): void => { this.isRefreshing0 = true; },
              onTimeout: (): void => { this.isRefreshing0 = false; }
            }) {
              this.exploreTabContent(0)
            }
          }

            if (this.reduceEffects) {
            PullToRefresh({
              reduceEffects: true,
              scroller: this.scrollers[1],
              iconTopOffset: 100,
              isRefreshing: this.isRefreshing1,
              onRefresh: (): void => { this.isRefreshing1 = true; },
              onTimeout: (): void => { this.isRefreshing1 = false; }
            }) {
              this.exploreTabContent(1)
            }
          } else {
            PullToRefresh({
              scroller: this.scrollers[1],
              iconTopOffset: 100,
              isRefreshing: this.isRefreshing1,
              onRefresh: (): void => { this.isRefreshing1 = true; },
              onTimeout: (): void => { this.isRefreshing1 = false; }
            }) {
              this.exploreTabContent(1)
            }
          }

            if (this.reduceEffects) {
            PullToRefresh({
              reduceEffects: true,
              scroller: this.scrollers[2],
              iconTopOffset: 100,
              isRefreshing: this.isRefreshing2,
              onRefresh: (): void => { this.isRefreshing2 = true; },
              onTimeout: (): void => { this.isRefreshing2 = false; }
            }) {
              this.exploreTabContent(2)
            }
          } else {
            PullToRefresh({
              scroller: this.scrollers[2],
              iconTopOffset: 100,
              isRefreshing: this.isRefreshing2,
              onRefresh: (): void => { this.isRefreshing2 = true; },
              onTimeout: (): void => { this.isRefreshing2 = false; }
            }) {
              this.exploreTabContent(2)
            }
          }
        }
        .layoutWeight(1).width('100%').clip(false)
        .loop(false).index(this.selectedTab)
        .indicator(this.showSwiperDots)
        .onChange((idx: number) => { this.onSwiperChange(idx); })
        .onAnimationStart((_index: number, targetIndex: number, _extraInfo: SwiperAnimationEvent) => {
          animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
            this.tabProgress = targetIndex;
            this.updateIndicatorOffset();
          });
        })
        .onGestureSwipe((index: number, extraInfo: SwiperAnimationEvent) => {
          const pageWidth = this.getWinWidth();
          const raw = index + (-extraInfo.currentOffset) / pageWidth;
          this.tabProgress = Math.max(0, Math.min(raw, this.tabNames.length - 1));
          this.updateIndicatorOffset();
        })
      }
      .width('100%').height('100%').expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      if (this.loadingMoreGearVisible) {
        Column() {
          GearCycle({ gearSize: 40, color: darkenColor(this.primaryColor, 0.2), refreshing: true })
        }
        .width('100%')
        .position({ bottom: 90, left: 0, right: 0 })
        .translate({ y: this.loadingMoreGearOffset })
        .opacity(this.loadingMoreGearOpacity)
        .zIndex(10)
      }
 
      if (this.showFabMenu) {
        Column().width('100%').height('100%').onClick(() => { this.showFabMenu = false; })
      }

      if (this.showHotTabMenu) {
        Column() {
          Column().width('100%').layoutWeight(1).onClick(() => { this.showHotTabMenu = false; })
          Column() {
            Row() {
              Text('选择榜单').fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark))
              Blank()
              Text('总榜固定，其余可增减').fontFamily(this.appFontFamily).fontSize(11).fontColor(textTertiary(this.isDark))
            }
            .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 8 })
            Grid() {
              ForEach(this.allHotTabNames, (name: string) => {
                GridItem() {
                  Row() {
                    Text(name)
                      .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textPrimary(this.isDark))
                      .halfLeading(true)
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)
                    if (name === '总榜') {
                      Text('固定').fontFamily(this.appFontFamily).fontSize(11).fontColor(textTertiary(this.isDark)).halfLeading(true).margin({ left: 4 })
                    } else {
                      Text(this.isHotTabEnabled(name) ? '-' : '+')
                        .fontFamily(this.appFontFamily).fontSize(16).fontColor('#FFFFFF')
                        .width(22).height(22).lineHeight(22).halfLeading(true).textAlign(TextAlign.Center)
                        .backgroundColor(this.isHotTabEnabled(name) ? '#E53935' : textAccent(this.primaryColor, this.isDark))
                        .borderRadius(11)
                        .margin({ left: 4 })
                        .onClick(() => { this.toggleHotTab(name); })
                    }
                  }
                  .width('100%').padding({ left: 10, right: 8, top: 6, bottom: 6 })
                  .backgroundColor(this.isHotTabEnabled(name) ? blendWithBg(this.primaryColor, 0.12, this.isDark) : (this.isDark ? '#2A2A2A' : '#F2F3F5'))
                  .borderRadius(18)
                }
              })
            }
            .columnsTemplate('1fr 1fr 1fr')
            .columnsGap(8).rowsGap(8)
            .width('100%').height(300)
            .padding({ left: 16, right: 16, bottom: 16 })
          }
          .width('100%')
          .backgroundColor(cardBg(this.isDark))
          .borderRadius({ topLeft: 16, topRight: 16 })
          .padding({ bottom: 24 })
        }
        .width('100%').height('100%')
        .backgroundColor('#33000000')
      }

      Column() {
        if (this.showFabMenu) {
          Column({ space: 8 }) {
            this.FabMenuRow($r('app.media.ic_refresh'), 'Refresh', (): void => { this.fabRefresh(); })
            this.FabMenuRow($r('app.media.ic_arrow_up'), '回到顶部', (): void => { this.fabScrollToTop(); })
          }
          .padding(12).borderRadius(16).backgroundColor(cardBg(this.isDark))
          .shadow({ radius: 8, color: shadowColor(this.isDark), offsetY: 2 })
          .margin({ bottom: 8 })
        }

        this.FabButton()
      }
      .alignItems(HorizontalAlign.Center).width(52)
      .position({ right: 16, bottom: 80 })
      .translate({ x: this.fabVisible ? (this.fabLeft ? -(this.getWinWidth() - 84) : 0) : (this.fabLeft ? -(this.getWinWidth() - 84) - 80 : 80) })
      .hitTestBehavior(this.fabVisible ? HitTestMode.Default : HitTestMode.None)

      if (this.refreshBanner) {
        Row() {
          Text(this.refreshBanner)
            .fontFamily(this.appFontFamily).fontSize(Math.round(13 * this.fontScale)).fontColor(textPrimary(this.isDark))
        }
        .padding({ left: 18, right: 18, top: 8, bottom: 8 })
        .backgroundColor(blendWithBg(this.primaryColor, 0.18, this.isDark, '#1E1E1E'))
        .borderRadius(20)
        .shadow({ radius: 6, color: shadowColor(this.isDark), offsetY: 2 })
        .width('100%').justifyContent(FlexAlign.Center)
        .position({ top: this.topInset + 10 })
        .opacity(this.refreshBannerOpacity)
        .zIndex(60)
      }
    }
    .width('100%').height('100%')
    .backgroundColor(this.bgColor)
    .onTouch((event: TouchEvent) => {
      if (!GripDetector.isEnabled() || GripDetector.isNativeAvailable()) return;
      const side = GripDetector.touchSide(event.touches);
      if (side === -1 && !this.fabLeft) {
        this.switchFabSide(true);
      } else if (side === 1 && this.fabLeft) {
        this.switchFabSide(false);
      }
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

  }

  @Builder
  FabMenuRow(iconRes: Resource, _label: string, action: () => void) {
    Row() {
      Image(iconRes).width(18).height(18).fillColor(textPrimary(this.isDark))
    }
    .padding({ top: 6, bottom: 6, left: 4, right: 4 })
    .borderRadius(8)
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
  TopicItem(topic: Dict, rank: number) {
    Row() {
      Text(String(rank + 1))
        .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontWeight(FontWeight.Bold)
        .fontColor(rank === 0 ? '#FF0000' : rank === 1 ? '#FF8800' : rank === 2 ? '#FFCC00' : textTertiary(this.isDark))
        .width(24).textAlign(TextAlign.Center)
      Text(this.getTopicName(topic))
        .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textPrimary(this.isDark)).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: 8 }).layoutWeight(1)
      if (getNum(topic, 'tag', 'discuss_flag') > 0) {
        if (getNum(topic, 'tag', 'discuss_flag') === 2) {
          Image($r('app.media.ic_hot')).width(14).height(14).fillColor('#FF6B35')
        }
        Text('热').fontFamily(this.appFontFamily).fontSize(11).fontColor('#FF6B35')
      }
    }
    .layoutWeight(1).height(36)
    .onClick(() => {
      NavigationHelper.navigate('pages/hottopic/TopicDetailPage', {
        topicId: getStr(topic, 'topicId', 'topic_id', 'id'),
        topicName: this.getTopicName(topic)
      });
    })
  }

  private getTopicName(topic: Dict): string {
    const name = getStr(topic, 'topicName', 'name', 'topic_name', 'title');
    if (name) return name;
    const obj = topic.actor_topic as Dict || topic.ztInfo as Dict || {};
    return getStr(obj, 'topic_name', 'name', 'title', 'topicName');
  }

  private getForumName(thread: Dict): string {
    const fi = thread.forumInfo as Dict | undefined;
    if (fi) return getStr(fi, 'name', 'forumName', 'forum_name');
    const fn = thread.forumName || thread.forum_name;
    if (typeof fn === 'string') return fn;
    if (fn && typeof fn === 'object') return getStr(fn as Dict, 'name', 'forumName', 'forum_name');
    const forum = thread.forum as Dict | undefined;
    if (forum) return getStr(forum, 'name', 'forumName', 'forum_name');
    return getStrObj(thread, 'fname', 'forum_name', 'forumName', 'forum');
  }

  private showLoadingGear(): void {
    this.loadingMoreGearVisible = true;
    animateTo({ duration: 200, curve: Curve.EaseOut }, (): void => {
      this.loadingMoreGearOffset = 0;
      this.loadingMoreGearOpacity = 1;
    });
  }

  private hideLoadingGear(): void {
    animateTo({ duration: 200, curve: Curve.EaseOut }, (): void => {
      this.loadingMoreGearOffset = 60;
      this.loadingMoreGearOpacity = 0;
    });
    setTimeout(() => {
      this.loadingMoreGearVisible = false;
    }, 260);
  }

  async loadMore(): Promise<void> {
    if (this.loadingMore) return;
    this.loadingMore = true;
    this.showLoadingGear();
    try {
      let data: Dict;
      if (this.selectedTab === 0) {
        if (!this.followingHasMore) { return; }
        if (this.followingPageTag) {
          data = await this.repo.loadUserLikeFlow(this.followingPageTag, 2);
        } else {
          this.followingPage++;
          data = await this.repo.loadPersonalized(this.followingPage);
        }
      } else if (this.selectedTab === 1) {
        data = await this.repo.loadPersonalized(this.recommendedPage);
      } else {
        if (this.selectedHotTabIndex === 0) {
          data = await this.repo.loadHotThreads('all');
        } else {
          const tabName = this.getHotTabName(this.selectedHotTabIndex);
          data = await this.searchRepo.searchThread(tabName, this.hotTabPage, 2);
        }
      }
      const threads: Dict[] = this.extractThreads(data);
      if (threads.length === 0) {
        if (this.selectedTab === 0) { this.followingHasMore = false; }
        else if (this.selectedTab === 1) { this.recommendedHasMore = false; }
        else { this.hotHasMore = false; }
        return;
      }
      let existing: Dict[];
      if (this.selectedTab === 0) existing = this.followingThreads;
      else if (this.selectedTab === 1) existing = this.recommendedThreads;
      else existing = this.hotThreads;
      const existingIds = new Set(existing.map(t => getStr(t, 'id', 'tid', 'threadId', 'thread_id')));
      const uniqueNew = threads.filter(t => !existingIds.has(getStr(t, 'id', 'tid', 'threadId', 'thread_id')));
      if (uniqueNew.length === 0) {
        if (this.selectedTab === 0) { this.followingHasMore = false; }
        else if (this.selectedTab === 1) { this.recommendedHasMore = false; }
        else { this.hotHasMore = false; }
        return;
      }
      if (this.selectedTab === 0) {
        if (this.followingPageTag) {
          const dd = (data.data as Dict) || data;
          this.followingPageTag = getStr(dd, 'pageTag', 'page_tag') || this.followingPageTag;
          this.followingRequestUnix = String(getNum(dd, 'requestUnix', 'request_unix') || this.followingRequestUnix);
          const fhm = dd['hasMore'] ?? dd['has_more'];
          this.followingHasMore = fhm === undefined || fhm === null ? true : Number(fhm) !== 0;
        }
        this.followingThreads = [...this.followingThreads, ...uniqueNew];
      } else if (this.selectedTab === 1) {
        this.recommendedThreads = [...this.recommendedThreads, ...uniqueNew];
      } else {
        this.hotThreads = [...this.hotThreads, ...uniqueNew];
      }
      this.saveToCache();
    } catch (e) {
      if (this.selectedTab === 0) { this.followingHasMore = false; }
      else if (this.selectedTab === 1) { this.recommendedHasMore = false; }
      else { this.hotHasMore = false; }
    } finally {
      this.loadingMore = false;
      this.hideLoadingGear();
    }
  }

  private chunkTopics(arr: Dict[]): Dict[][] {
    const result: Dict[][] = [];
    for (let i = 0; i < arr.length; i += 2) {
      result.push(arr.slice(i, i + 2));
    }
    return result;
  }

  private extractThreads(data: Dict): Dict[] {
    const raw = this.extractThreadsRaw(data);
    if (raw.length === 0) return raw;
    const blockRepo = BlockRepository.getInstance();
    return raw.filter((t: Dict) => {
      const forumName = this.getForumNameOfThread(t);
      const author = t.author as Dict | undefined;
      const uid = Number((author ? getStr(author, 'id', 'user_id', 'uid') : '') || getStr(t, 'authorId', 'author_id', 'authorUid', 'author_uid', 'uid', 'userId', 'user_id') || 0);
      const fp = (t.firstPost as Dict) || ((t as Dict)['first_post'] as Dict);
      const title = getStr(t, 'title', 'threadTitle', 'thread_title', 'name', 'postName') || (fp ? getStr(fp, 'title', 'threadTitle', 'thread_title') : '') || '';
      const abs = t._abstract;
      let abstractStr = '';
      if (Array.isArray(abs) && abs.length > 0) {
        const parts: string[] = [];
        for (const it of abs as Dict[]) {
          const c = getStr(it, 'c', 'text');
          if (c) parts.push(c);
        }
        abstractStr = parts.join(' ');
      }
      if (!abstractStr) abstractStr = getStr(t, 'abstract', 'summary', 'abstractText', 'abstract_text') || '';
      return !blockRepo.isThreadBlocked(forumName, uid, title, abstractStr);
    });
  }

  private getForumNameOfThread(thread: Dict): string {
    const fi = thread.forumInfo as Dict | undefined;
    if (fi) return getStr(fi, 'name', 'forumName', 'forum_name');
    const fn = thread.forumName || thread.forum_name;
    if (typeof fn === 'string') return fn;
    if (fn && typeof fn === 'object') return getStr(fn as Dict, 'name', 'forumName', 'forum_name');
    const forum = thread.forum as Dict | undefined;
    if (forum) return getStr(forum, 'name', 'forumName', 'forum_name');
    const fname = getStrObj(thread, 'fname', 'forum_name', 'forumName', 'forum');
    if (fname && typeof fname !== 'object') return fname;
    return '';
  }

  private extractThreadsRaw(data: Dict): Dict[] {
    if (!data) return [];
    if (Array.isArray(data)) return data as Dict[];
    const d = (data.data as Dict) || data;
    if (Array.isArray(d)) return d as Dict[];

    // Handle ConcernData (userlike API): d.threadInfo[] each with threadList, recommendType
    const ti = d.threadInfo as Dict[] | undefined;
    if (Array.isArray(ti) && ti.length > 0) {
      const hasConcernData = ti.some((item: Dict) => {
        const tl = item.threadList || item.thread_list;
        return tl && typeof tl === 'object' && !Array.isArray(tl);
      });
      if (hasConcernData) {
        const result: Dict[] = [];
        for (const item of ti) {
          const type = item.recommendType !== undefined ? Number(item.recommendType) : 1;
          if (type === 1) {
            const inner = item.threadList || item.thread_list;
            if (inner && typeof inner === 'object' && !Array.isArray(inner)) {
              if ((inner as Dict)['media'] === undefined && item['media'] !== undefined)
                (inner as Dict)['media'] = item['media'];
              if ((inner as Dict)['imageUrls'] === undefined && item['imageUrls'] !== undefined)
                (inner as Dict)['imageUrls'] = item['imageUrls'];
              if ((inner as Dict)['firstPostContent'] === undefined && item['firstPostContent'] !== undefined)
                (inner as Dict)['firstPostContent'] = item['firstPostContent'];
              if ((inner as Dict)['first_post_content'] === undefined && item['first_post_content'] !== undefined)
                (inner as Dict)['first_post_content'] = item['first_post_content'];
              result.push(inner as Dict);
            } else {
              result.push(item);
            }
          }
        }
        if (result.length > 0) return result;
      }
    }

    const candidates = ['thread_list', 'thread_info', 'threadList', 'threadInfo', 'post_list', 'postList', 'feed', 'data_list', 'dataList', 'list', 'items', 'thread', 'posts', 'like_post', 'likePost'];
    for (const key of candidates) {
      const val = d[key];
      if (Array.isArray(val) && (val as Dict[]).length > 0) {
        return (val as Dict[]).map((item: Dict) => {
          const inner = item.threadList || item.thread_list;
          if (inner && Array.isArray(inner) && inner.length > 0) {
            const innerItem = inner[0] as Dict;
            if ((innerItem as Dict)['media'] === undefined && (item as Dict)['media'] !== undefined)
              (innerItem as Dict)['media'] = (item as Dict)['media'];
            if ((innerItem as Dict)['imageUrls'] === undefined && (item as Dict)['imageUrls'] !== undefined)
              (innerItem as Dict)['imageUrls'] = (item as Dict)['imageUrls'];
            if ((innerItem as Dict)['firstPostContent'] === undefined && (item as Dict)['firstPostContent'] !== undefined)
              (innerItem as Dict)['firstPostContent'] = (item as Dict)['firstPostContent'];
            if ((innerItem as Dict)['first_post_content'] === undefined && (item as Dict)['first_post_content'] !== undefined)
              (innerItem as Dict)['first_post_content'] = (item as Dict)['first_post_content'];
            return innerItem;
          }
          return item;
        });
      }
    }
    const concern = (d.concernData || d.concern_data) as Dict;
    if (concern) {
      const ti2 = (concern.threadInfo || concern.thread_info) as Dict[];
      if (Array.isArray(ti2) && ti2.length > 0) {
        return ti2.map((item: Dict) => {
          const inner = item.threadList || item.thread_list;
          if (inner && Array.isArray(inner) && inner.length > 0) {
            const innerItem = inner[0] as Dict;
            if ((innerItem as Dict)['media'] === undefined && (item as Dict)['media'] !== undefined)
              (innerItem as Dict)['media'] = (item as Dict)['media'];
            if ((innerItem as Dict)['imageUrls'] === undefined && (item as Dict)['imageUrls'] !== undefined)
              (innerItem as Dict)['imageUrls'] = (item as Dict)['imageUrls'];
            if ((innerItem as Dict)['firstPostContent'] === undefined && (item as Dict)['firstPostContent'] !== undefined)
              (innerItem as Dict)['firstPostContent'] = (item as Dict)['firstPostContent'];
            if ((innerItem as Dict)['first_post_content'] === undefined && (item as Dict)['first_post_content'] !== undefined)
              (innerItem as Dict)['first_post_content'] = (item as Dict)['first_post_content'];
            return innerItem;
          }
          return item;
        });
      }
    }
    console.info('TiebaLite: extractThreads no match, first-level keys=' + Object.keys(data).join(',') + ' data-keys=' + Object.keys(d).join(','));
    return [];
  }

  private extractTopics(data: Dict): Dict[] {
    if (!data) return [];
    const d = (data.data as Dict) || data;
    if (d.topic_list && (d.topic_list as Dict[]).length > 0) return d.topic_list as Dict[];
    if (d.topicList && (d.topicList as Dict[]).length > 0) return d.topicList as Dict[];
    if (d.topics && (d.topics as Dict[]).length > 0) return d.topics as Dict[];
    if (Array.isArray(data)) return data as Dict[];
    if (Array.isArray(d)) return d as Dict[];
    return [];
  }
}

