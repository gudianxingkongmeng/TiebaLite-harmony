import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import window from '@ohos.window';
import display from '@ohos.display';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import ThreadStoreRepository from '../../core/repository/ThreadStoreRepository';
import PbPageRepository from '../../core/repository/PbPageRepository';
import DatabaseManager from '../../core/storage/DatabaseManager';
import PreferencesManager from '../../core/storage/PreferencesManager';
import ThreadCard from '../../components/ThreadCard';
import LoadingState from '../../components/LoadingState';
import ErrorState from '../../components/ErrorState';
import GearLoading from '../../components/GearLoading';
import GearCycle from '../../components/GearCycle';
import PullToRefresh from '../../components/PullToRefresh';
import { Dict } from '../../core/types/Dict';
import { getStr, getNum, blendWithBg, pageBg, cardBg, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor, withAlpha, glassTopBarSurface, glassTopBarEffect, glassBlurLevel, glassBackdropBlur } from '../../core/utils/DataHelper';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';
import promptAction from '@ohos.promptAction';
import BackToTopButton from '../../components/BackToTopButton';

let _storeInitialLoadDone: boolean = false;

@Entry
@Component
struct ThreadStorePage {
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  reduceEffects: boolean = false;
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @State threads: Dict[] = [];
  @State page: number = 0;
  @State hasMore: boolean = true;
  @State loading: boolean = true;
  @State loadingMore: boolean = false;
  @State error: string = '';
  @State showMenu: boolean = false;
  @State menuThreadId: number = 0;
  @State menuPostId: number = 0;
  @State uncollectedIds: number[] = [];
  @State @Watch('onRefreshStateChange') isRefreshing: boolean = false;
  @State pullDistance: number = 0;
  @State pullRefreshing: boolean = false;
  @State scrollTop: number = 0;
  @State topInset: number = 24;
  @StorageLink('headerAlpha') headerAlpha: number = 25;
  private scroller: Scroller = new Scroller();

  private repo: ThreadStoreRepository = ThreadStoreRepository.getInstance();
  private static _agreeCache: Map<number, Dict> = new Map();
  // 静态守卫：多次进入收藏页时各页面实例会同时触发回填，需要跨实例防重入
  private static _enriching: boolean = false;
  private _busyStoreIds: Set<number> = new Set();

  aboutToAppear(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      window.getLastWindow(ctx).then((win: window.Window) => {
        const avoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        if (avoidArea.topRect.height > 0) {
          const density = display.getDefaultDisplaySync().densityPixels;
          this.topInset = Math.max(20, Math.round(avoidArea.topRect.height / density));
        }
      }).catch(() => { });
    } catch (e) { }
    if (!_storeInitialLoadDone) {
      void this.loadStores();
      _storeInitialLoadDone = true;
    } else {
      this.loading = false;
      this.error = '';
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
  }

  onPageHide(): void {
    const v = AppStorage.get<number>('pageHideTick') || 0;
    AppStorage.SetOrCreate('pageHideTick', v + 1);
  }

  async loadStores(): Promise<void> {
    this.loading = true;
    this.error = '';
    this.page = 0;
    this.hasMore = true;
    try {
      const data: Dict | null = await this.loadStoresWithRetry(0);
      if (!data) {
        this.error = '网络波动，请稍后重试';
        return;
      }
      this.threads = this.extractThreads(data);
      // 延后加载点赞数，避免阻塞列表首屏与触发风控
      setTimeout(() => { void this.enrichAgree(); }, 600);
    } catch (e) {
      const msg = (e as Dict)?.msg as string || (e as Dict)?.message as string || '加载失败';
      this.error = msg.indexOf('格式') >= 0 ? '网络波动，请稍后重试' : msg;
    } finally {
      this.loading = false;
    }
  }

  /**
   * HttpClient 已对空响应做过 3 次底层重试，这里只在页面层兜一层，
   * 避免极端情况下用户看到空白页。重试次数刻意保持很小，防止请求风暴。
   */
  private async loadStoresWithRetry(page: number): Promise<Dict | null> {
    for (let attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await new Promise<void>((resolve: () => void) => { setTimeout(() => { resolve(); }, 400); });
      }
      try {
        return await this.repo.loadStores(page);
      } catch (e) {
        const err = e as Dict;
        const msg = String(err?.msg || err?.message || '');
      }
    }
    return null;
  }

  private onRefreshStateChange(): void {
    if (this.isRefreshing) {
      this.pullRefreshing = true;
      void this.onPullRefresh();
    } else {
      this.pullRefreshing = false;
      this.pullDistance = 0;
    }
  }

  async onPullRefresh(): Promise<void> {
    this.page = 0;
    this.hasMore = true;
    try {
      const data: Dict | null = await this.loadStoresWithRetry(0);
      if (!data) {
        promptAction.showToast({ message: '刷新失败，请稍后重试', duration: 1500 });
        return;
      }
      this.threads = this.extractThreads(data);
      // 延后加载点赞数，避免阻塞列表首屏与触发风控
      setTimeout(() => { void this.enrichAgree(); }, 600);
    } catch (_e) {}
    this.isRefreshing = false;
  }

  /**
   * 从本地浏览历史中回填点赞数。
   * 早期版本会为每条收藏并发请求 /c/f/pb/page 拉取最新点赞数，
   * 但收藏条目多时会瞬间打出上百个请求，导致服务端返回空响应（empty response），
   * 且点赞数本身只是列表卡片上的次要信息，因此改为纯本地回填，不再发起任何网络请求。
   */
  private async enrichAgree(): Promise<void> {
    if (ThreadStorePage._enriching) return;
    ThreadStorePage._enriching = true;
    try {
      try {
        const histories = await DatabaseManager.getInstance().getThreadHistories(500);
        for (const h of histories) {
          if (!h.data) continue;
          let parsed: Dict | null = null;
          try { parsed = JSON.parse(h.data) as Dict; } catch (_e) {}
          const a = parsed?.agree as Dict | undefined;
          if (a && !ThreadStorePage._agreeCache.has(h.id)) ThreadStorePage._agreeCache.set(h.id, a);
        }
      } catch (_e) {}
      this.threads = this.threads.map((t: Dict) => {
        if (t.agree !== undefined) return t;
        const tid = Number(t.id || t.tid || t.thread_id || 0);
        if (tid <= 0) return t;
        const cached = ThreadStorePage._agreeCache.get(tid);
        if (!cached) return t;
        const copy: Dict = {};
        for (const k of Object.keys(t)) copy[k] = t[k];
        copy['agree'] = cached;
        // 同步点赞数缓存并触发 ThreadCard 刷新（组件只在创建时读一次 agree）
        const cachedN = getNum(cached, 'agree_num', 'agreeNum', 'count', 'num');
        if (cachedN > 0) {
          void PreferencesManager.getInstance().putString('liked_count_tid_' + tid, String(cachedN)).catch(() => {});
        }
        void PreferencesManager.getInstance().putString('liked_tid_' + tid, Number(cached.has_agree ?? cached.hasAgree ?? 0) === 1 ? '1' : '0').catch(() => {});
        try { AppStorage.SetOrCreate('likedVersion', (AppStorage.Get<number>('likedVersion') ?? 0) + 1); } catch (_e) {}
        return copy;
      });
    } finally {
      ThreadStorePage._enriching = false;
    }
  }

  build() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor(pageBg(this.isDark))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      Column() {
        Row() {
          Image($r('app.media.ic_arrow_back')).width(22).height(22).fillColor(textPrimary(this.isDark))
            .onClick(() => router.back())
          Text('收藏帖').fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark))
            .margin({ left: 12 })
          Blank()
        }
        .padding({ left: 12, right: 12, bottom: 12, top: 12 + this.topInset })
        .width('100%')
        .backgroundColor(glassTopBarSurface(pageBg(this.isDark), this.isDark, this.headerAlpha))
        .backdropBlur(glassBackdropBlur(this.headerAlpha, 14))
        .backgroundEffect(glassTopBarEffect(this.headerAlpha))
        .border({ width: { bottom: 1 }, color: dividerColor(this.isDark) })
        .position({ x: 0, y: 0 })
        .zIndex(2)

        if (this.loading) {
          LoadingState({ message: '加载中...' })
        } else if (this.error.length > 0) {
          ErrorState({ message: this.error, onRetryAction: (): void => { void this.loadStores(); } })
        } else if (this.threads.length === 0) {
          Text('暂无收藏帖')
            .fontFamily(this.appFontFamily).fontSize(16).fontColor(textTertiary(this.isDark))
            .width('100%').textAlign(TextAlign.Center).padding(48)
        } else {
            PullToRefresh({
              scroller: this.scroller,
              reduceEffects: this.reduceEffects,
              onRefresh: (): void => { this.isRefreshing = true; },
              onTimeout: (): void => { this.isRefreshing = false; }
            }) {
              List({ space: 0, scroller: this.scroller }) {
                ListItem() {
                  Column() {
                    Blank().height(46 + this.topInset)
                  }
                  .width('100%')
                }
                ForEach(this.threads, (thread: Dict, index: number) => {
                  ListItem() {
                    ThreadCard({
                      thread: thread,
                      isDeleted: (thread as Dict)._isDeleted === true,
                      noMedia: true,
                      thumbRight: true,
                      storeMode: true,
                      onCardClick: (): void => {
                        const innerThread = (thread.thread || thread.threadList || thread.thread_list || thread) as Dict;
                        const tid = getStr(innerThread, 'id', 'tid', 'threadId', 'thread_id') || getStr(thread, 'id', 'tid', 'threadId', 'thread_id') || '0';
                        // 跳到用户收藏时标记的那一楼（mark_pid），对齐安卓原版；
                        // 官方 app 收藏的记录可能只带 post_no（楼层号），一并传下去做回退定位
                        const markPid = getStr(thread, 'mark_pid', 'markPid', 'mark_post_id') ||
                          getStr(innerThread, 'mark_pid', 'markPid', 'mark_post_id') || '0';
                        const floorNo = getStr(thread, 'post_no', 'postNo') ||
                          getStr(innerThread, 'post_no', 'postNo') || '0';
                        NavigationHelper.navigate('pages/thread/ThreadPage', {
                          threadId: tid,
                          postId: markPid !== '0' ? markPid : '',
                          markPid: markPid !== '0' ? markPid : '',
                          floorNo: floorNo !== '0' ? floorNo : '',
                          forumId: String(thread.forumId || innerThread.forumId || 0),
                          forumName: String(thread.forumName || innerThread.forumName || ''),
                          isCollected: '1'
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
                    })
                    .gesture(
                      GestureGroup(GestureMode.Exclusive,
                        LongPressGesture({ repeat: false }).onAction(() => {
                          this.menuThreadId = Number(getStr(thread, 'id', 'tid', 'threadId', 'thread_id') || '0');
                          this.menuPostId = Number(getStr(thread, 'mark_pid', 'markPid', 'min_pid', 'minPid', 'pid') || '0');
                          this.showMenu = true;
                        })
                      )
                    )
                  }
                  .margin({ left: 16, right: 16, top: 6, bottom: 6 })
                  .swipeAction({
                    // 左滑露出收藏/取消收藏（end=右缘向左滑出，对齐通话记录左滑删除效果）
                    end: (): void => {
                      const tid = Number(getStr(thread, 'id', 'tid', 'threadId', 'thread_id') || '0');
                      // 优先用 mark_pid（用户收藏时标记的那一楼），回退到 min_pid（首楼）
                      const pid = Number(getStr(thread, 'mark_pid', 'markPid', 'min_pid', 'minPid', 'pid', 'post_id', 'first_post_id', 'firstPostId') || '0');
                      this.deleteActionBuilder(tid, pid, this.uncollectedIds.indexOf(tid) < 0);
                    },
                    edgeEffect: SwipeEdgeEffect.Spring
                  })
                }, (thread: Dict, index: number): string => {
                  const tid = getStr(thread, 'id', 'tid', 'threadId', 'thread_id');
                  return tid.length > 0 ? tid : 'store_idx_' + index;
                })

                if (this.hasMore) {
                  ListItem() {
                    Row() {
                      GearLoading({ gearSize: 18, color: textTertiary(this.isDark), text: '加载更多...' })
                    }
                    .width('100%').padding(12)
                    .justifyContent(FlexAlign.Center)
                    .onClick(() => { void this.loadMore(); })
                  }
                }
              }
              .width('100%')
              .layoutWeight(1)
              .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
              .backgroundColor(pageBg(this.isDark))
              .edgeEffect(EdgeEffect.None)
              .onReachEnd(() => {
                if (this.hasMore) {
                  void this.loadMore();
                }
              })
              .onDidScroll(() => {
                this.scrollTop = this.scroller.currentOffset().yOffset;
              })
            }
          }

        if (this.showMenu) {
          Column() {
            Column()
              .width('100%').layoutWeight(1)
              .onClick(() => { this.showMenu = false; })
            Column() {
              Row() {
                Text(this.uncollectedIds.indexOf(this.menuThreadId) < 0 ? '取消收藏' : '收藏').fontFamily(this.appFontFamily).fontSize(15).fontColor(this.uncollectedIds.indexOf(this.menuThreadId) < 0 ? '#FF4444' : this.primaryColor)
              }
              .height(44).padding({ left: 16, right: 16 })
              .onClick(() => {
                this.showMenu = false;
                if (this.menuThreadId > 0) {
                  if (this.uncollectedIds.indexOf(this.menuThreadId) < 0) {
                    void this.removeStore(this.menuThreadId);
                  } else {
                    void this.reStore(this.menuThreadId, this.menuPostId);
                  }
                }
              })
            }
            .backgroundColor(cardBg(this.isDark)).borderRadius(12)
            .shadow({ radius: 16, color: shadowColor(this.isDark), offsetY: 8 })
            .margin({ bottom: 80 })
          }
          .width('100%').height('100%')
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.End)
          .backgroundColor('#33000000')
        }
      }
      .width('100%').height('100%')
      .justifyContent(FlexAlign.Start)
      .backgroundColor(pageBg(this.isDark))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      BackToTopButton({
        scrollTop: $scrollTop,
        onTopClick: () => { this.scroller.scrollEdge(Edge.Top); }
      })
    }
    .width('100%').height('100%')
    .backgroundColor(pageBg(this.isDark))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  private extractThreads(data: Dict): Dict[] {
    if (!data) return [];
    let list: Dict[] | null = null;
    if (Array.isArray(data)) return data as Dict[];
    for (const root of [data, data.data as Dict, (data.data as Dict)?.data as Dict]) {
      if (!root) continue;
      for (const key of ['store_thread', 'thread_list', 'thread_info', 'post_list']) {
        const v = (root as Dict)[key];
        if (Array.isArray(v) && v.length > 0) { list = v as Dict[]; break; }
      }
      if (list) break;
    }
    return (list || []).map((t: Dict, idx: number) => {
      const inner = (t.thread || t.threadList || t.thread_list || t) as Dict;
      if (inner !== t) {
        for (const key of Object.keys(t)) {
          if (key === 'thread' || key === 'threadList' || key === 'thread_list') continue;
          if (inner[key] === undefined && t[key] !== undefined) {
            inner[key] = t[key];
          }
        }
      }
      // extract media (images + video posters) from firstPostContent
      const existingMedia = inner.media as object;
      const needMedia = !existingMedia || !Array.isArray(existingMedia) || (existingMedia as object[]).length === 0;
      let builtMedia: Dict[] | null = null;
      if (needMedia) {
        const contentSources: object[] = (inner.firstPostContent || inner.first_post_content || inner._abstract || inner.abstract || inner.content || inner.richAbstract || inner.rich_abstract || []) as object[];
        if (Array.isArray(contentSources) && contentSources.length > 0) {
          const imgs: Dict[] = [];
          for (const ct of contentSources as Dict[]) {
            const itemType = Number(ct.type);
            if (itemType === 1 || itemType === 3) {
              const src = getStr(ct, 'originSrc', 'src', 'origin_src', 'bigPic', 'big_pic', 'smallPic', 'small_pic', 'url');
              if (src) {
                const httpsSrc = src.startsWith('https://') ? src : src.startsWith('http://') ? 'https://' + src.substring(7) : 'https:' + src;
                imgs.push({ src: httpsSrc, width: getNum(ct, 'width', 'originWidth', 'origin_width', 'bigWidth', 'big_width'), height: getNum(ct, 'height', 'originHeight', 'origin_height', 'bigHeight', 'big_height') } as Dict);
              }
            } else if (itemType === 5) {
              const poster = getStr(ct, 'bsrc', 'poster', 'posterUrl', 'cover', 'coverUrl', 'thumbnail', 'pic', 'src');
              if (poster) {
                imgs.push(ct as Dict);
              }
            }
          }
          if (imgs.length > 0) builtMedia = imgs;
        }
      }
      // also scan top-level thread keys for video info (fallback)
      if (!builtMedia) {
        let vidCover = '';
        const vi = (inner.videoInfo || inner.video_info) as Dict;
        if (vi) {
          vidCover = getStr(vi, 'thumbnailUrl', 'thumbnail_url', 'poster', 'cover', 'src', 'pic');
        } else {
          for (const k of Object.keys(inner)) {
            const kl = k.toLowerCase();
            if (kl.includes('video') || kl.includes('cover') || kl.includes('poster') || kl.includes('thumb')) {
              const v = inner[k];
              if (typeof v === 'string' && v.length > 0 && v.length < 500) {
                vidCover = v;
                break;
              }
              if (typeof v === 'object' && v !== null) {
                vidCover = getStr(v as Dict, 'thumbnailUrl', 'thumbnail_url', 'poster', 'cover', 'src', 'pic', 'url');
                if (vidCover) break;
              }
            }
          }
        }
        if (vidCover) {
          builtMedia = [{ type: 5, bsrc: vidCover, is_video: 1 } as Dict];
        }
      }
      if (builtMedia) inner.media = builtMedia;

      // detect deleted status from wrapper or direct item
      const deleted = Number(t.is_deleted ?? t.is_delete ?? t.isDel ?? t.del ?? 0);
      const notExist = Number(t.is_exist ?? t.isExist ?? 1);
      inner._isDeleted = deleted === 1 || notExist === 0;
      return inner;
    });
  }

  @Builder
  deleteActionBuilder(threadId: number, postId: number, isCollected: boolean) {
    // 右缘按钮（固定宽 92vp=80 按钮+12 右边距，滑动范围即按钮宽度，对齐通话记录左滑删除样式）
    Row() {
      Text(isCollected ? '取消收藏' : '收藏')
        .fontFamily(this.appFontFamily).fontSize(14).fontColor(Color.White).fontWeight(FontWeight.Medium)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width(92)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(isCollected ? '#FF4444' : this.primaryColor)
    .borderRadius(12)
    .margin({ right: 12 })
    .onClick(() => {
      if (threadId > 0) {
        if (isCollected) { void this.removeStore(threadId); } else { void this.reStore(threadId, postId); }
      }
    })
  }

  private async toggleStore(threadId: number, postId: number, collected: boolean): Promise<void> {
    if (this._busyStoreIds.has(threadId)) return;
    this._busyStoreIds.add(threadId);
    try {
      if (collected) {
        try {
          await this.repo.removeStore(threadId);
          this.uncollectedIds = this.uncollectedIds.concat(threadId);
          // 同步本地收藏状态（帖子页 loadLocalLikeState 读取 'collected_tid_<tid>'），
          // 避免取消收藏后重新进入帖子页仍显示"已收藏"点亮
          void PreferencesManager.getInstance().putString('collected_tid_' + threadId, '0').catch(() => {});
          promptAction.showToast({ message: '已取消收藏', duration: 1000 });
        } catch (e) {
          console.error('TiebaLite: removeStore failed code=' + String((e as Dict).code) + ' msg=' + String((e as Dict).msg));
          promptAction.showToast({ message: '取消收藏失败 [' + String((e as Dict).code) + '] ' + String((e as Dict).msg || ''), duration: 2000 });
        }
      } else {
        try {
          await this.repo.addStore(threadId, postId);
          this.uncollectedIds = this.uncollectedIds.filter(id => id !== threadId);
          void PreferencesManager.getInstance().putString('collected_tid_' + threadId, '1').catch(() => {});
          promptAction.showToast({ message: '已收藏', duration: 1000 });
        } catch (e) {
          console.error('TiebaLite: addStore failed code=' + String((e as Dict).code) + ' msg=' + String((e as Dict).msg));
          promptAction.showToast({ message: '收藏失败 [' + String((e as Dict).code) + '] ' + String((e as Dict).msg || ''), duration: 2000 });
        }
      }
    } finally {
      this._busyStoreIds.delete(threadId);
    }
  }

  private removeStore(threadId: number): Promise<void> {
    return this.toggleStore(threadId, 0, true);
  }

  private reStore(threadId: number, postId: number): Promise<void> {
    // pid 缺失时回退到首楼 id，避免服务端收到 pid=0 导致收藏归属错乱
    let pid = postId;
    if (!pid || pid <= 0) {
      const t = this.threads.find((x: Dict) => Number(getStr(x, 'id', 'tid', 'threadId', 'thread_id') || '0') === threadId);
      pid = t ? Number(getStr(t, 'min_pid', 'minPid', 'pid', 'post_id') || '0') : 0;
    }
    return this.toggleStore(threadId, pid, false);
  }

  private async loadMore(): Promise<void> {
    if (!this.hasMore || this.loadingMore) return;
    this.loadingMore = true;
    const nextPage = this.page + 1;
    try {
      const data: Dict | null = await this.loadStoresWithRetry(nextPage);
      if (!data) {
        this.hasMore = true;
        promptAction.showToast({ message: '加载更多失败，请重试', duration: 1500 });
        return;
      }
      const more: Dict[] = this.extractThreads(data);
      if (more.length === 0) { this.hasMore = false; return; }
      const existingIds = new Set(this.threads.map(t => getStr(t, 'id', 'tid', 'threadId', 'thread_id')));
      const uniqueNew = more.filter(t => !existingIds.has(getStr(t, 'id', 'tid', 'threadId', 'thread_id')));
      if (uniqueNew.length === 0) { this.hasMore = false; return; }
      this.threads = [...this.threads, ...uniqueNew];
      this.page = nextPage;
      this.hasMore = more.length >= 50;
      // 延后加载点赞数，避免阻塞列表首屏与触发风控
      setTimeout(() => { void this.enrichAgree(); }, 600);
    } catch (e) {
      // 保留 hasMore，允许用户再次点击「加载更多」重试
      this.hasMore = true;
    } finally {
      this.loadingMore = false;
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

