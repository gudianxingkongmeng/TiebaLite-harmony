import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { KeyboardAvoidMode } from '@ohos.arkui.UIContext';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import SearchRepository from '../../core/repository/SearchRepository';
import PbPageRepository from '../../core/repository/PbPageRepository';
import ThreadCard from '../../components/ThreadCard';
import Avatar from '../../components/Avatar';
import GearLoading from '../../components/GearLoading';
import GearCycle from '../../components/GearCycle';
import PullToRefresh from '../../components/PullToRefresh';
import { Dict } from '../../core/types/Dict';
import { getStr, getNum, buildPortraitUrl, blendWithWhite, blendWithBg, textAccent, pageBg, textPrimary, textSecondary, textTertiary, darkenColor, dividerColor, shadowColor, withAlpha, primaryContainer, onPrimaryContainer } from '../../core/utils/DataHelper';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';
import { GripDetector } from '../../core/utils/GripDetector';

@Entry
@Component
struct SearchPage {
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  @StorageLink('showSwiperDots') showSwiperDots: boolean = true;
  reduceEffects: boolean = false;
  @StorageLink('fontScale') fontScale: number = 1.0;
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @StorageLink('searchBoxRound') searchBoxRound: number = 100;
  @StorageLink('headerAlpha') headerAlpha: number = 25;
  @StorageLink('headerTint') headerTint: number = 8;
  @StorageLink('cardStyle') cardStyle: number = 0;
  @State bgColor: string = pageBg(AppStorage.Get<boolean>('isDarkTheme') ?? false);
  @StorageProp('hideOnScroll') hideOnScroll: boolean = true;
  @State keyword: string = '';
  @State forumName: string = '';
  @State selectedTab: number = 1;
  @State tabProgress: number = 1;
  @State tabIndicatorOffset: number = 0;
  @State indicatorWidth: number = 20;
  @State tabBarWidth: number = 0;
  @State selectedScope: number = 0;
  @State sortMode: number = 2;
  @State threadResults: Dict[] = [];
  @State forumResults: Dict[] = [];
  @State userResults: Dict[] = [];
  @State userList: Dict[] = [];
  @State searchHistory: string[] = [];
  @State showResults: boolean = false;
  @State refreshKey: number = 0;
  @State searching: boolean = false;
  @State showSortPopup: boolean = false;
  @State showScopeDD: boolean = false;
  @State showSortDD: boolean = false;
  @State suggestions: string[] = [];
  @State showSuggestions: boolean = false;
  @State showScrollTop: boolean = false;
  @State scrollTop: number = 0;
  @State fabLeft: boolean = false;
  @StorageLink('fabRadius') fabRadius: number = 60;
  private fabTimer: number = -1;
  @StorageLink('gripSide') @Watch('onGripSideChanged') gripSide: number = 0;
  @State searchBarVisible: boolean = true;
  @State @Watch('onFsRefreshChange') fsRefreshing: boolean = false;
  @State @Watch('onForumRefreshChange') forumRefreshing: boolean = false;
  @State @Watch('onThreadRefreshChange') threadRefreshing: boolean = false;
  @State @Watch('onUserRefreshChange') userRefreshing: boolean = false;
  @State searchPage: number = 1;
  @State searchHasMore: boolean = true;
  @State searchLoadingMore: boolean = false;
  @State pullDistance: number = 0;
  @State pullRefreshing: boolean = false;
  private lastFabScrollY: number = 0;

  private scrollers: Scroller[] = [new Scroller(), new Scroller(), new Scroller(), new Scroller()];
  private repo: SearchRepository = SearchRepository.getInstance();
  private suggestionTimeoutId: number = -1;
  private get isForumSearch(): boolean { return this.forumName.length > 0; }

  private async loadTabData(index: number): Promise<void> {
    if (index === 0 && this.forumResults.length === 0) { await this.searchForums(); }
    else if (index === 1 && this.threadResults.length === 0) { await this.searchThreads(); }
    else if (index === 2 && this.userResults.length === 0) { await this.searchUsers(); }
  }

  private switchTab(index: number): void {
    if (this.selectedTab === index) return;
    animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
      this.selectedTab = index;
      this.tabProgress = index;
      this.updateIndicatorOffset();
    });
    if (this.showResults) this.loadTabData(index);
  }

  private onSearchScroll(scIdx: number): void {
    const y = this.scrollers[scIdx].currentOffset().yOffset;
    this.scrollTop = y;
    const delta = y - this.lastFabScrollY;
    this.lastFabScrollY = y;
    if (Math.abs(delta) > 2000 || Math.abs(delta) < 0.5) return;
    if (delta > 5) {
      if (this.showScrollTop) {
        animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => { this.showScrollTop = false; });
      }
      if (this.hideOnScroll && this.searchBarVisible) { this.searchBarVisible = false; }
    } else if (delta < -5) {
      if (y > 500 && !this.showScrollTop) {
        animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => { this.showScrollTop = true; });
      }
      if (this.hideOnScroll && !this.searchBarVisible) { this.searchBarVisible = true; }
    }
  }

  private scrollResultsToTop(): void {
    const idx = this.isForumSearch ? 0 : 1 + this.selectedTab;
    this.scrollers[idx].scrollEdge(Edge.Top);
  }

  @Builder
  private historyContent(): void {
    Column() {
      Blank().height(104)
      Row() {
        Text('搜索历史').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark))
        Blank()
        Text('清空').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark))
          .onClick(() => {
            AlertDialog.show({
              title: '清空搜索历史',
              message: '确定要清空吗？',
              primaryButton: {
                value: '取消',
                action: () => {}
              },
              secondaryButton: {
                value: '确定',
                action: async () => {
                  await this.repo.clearSearchHistory();
                  this.searchHistory = [];
                }
              },
              cancel: () => {}
            });
          })
      }
      .width('100%').padding(12)
      if (this.searchHistory.length === 0) {
        Text('暂无搜索历史').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark)).padding(24)
      } else {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.searchHistory, (kw: string, idx: number) => {
            Text(kw)
              .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textPrimary(this.isDark))
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor(blendWithBg(this.primaryColor, 0.12, this.isDark, '#1E1E1E'))
              .borderRadius(10)
              .margin({ right: 8, bottom: 8 })
              .onClick(() => {
                this.keyword = kw;
                this.doSearch();
              })
              .gesture(LongPressGesture({ repeat: false, duration: 400 })
                .onAction(() => {
                  void this.repo.deleteSearchHistory(kw);
                  this.searchHistory = this.searchHistory.filter((k: string) => k !== kw);
                  promptAction.showToast({ message: '已删除', duration: 1000 });
                }))
          })
        }
        .width('100%').padding({ left: 12, right: 12 })
      }
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  private onFsRefreshChange(): void {
    if (this.fsRefreshing) {
      this.pullRefreshing = true;
      void this.refreshForumSearch();
    } else {
      this.pullRefreshing = false;
      this.pullDistance = 0;
    }
  }
  private onForumRefreshChange(): void {
    if (this.forumRefreshing) {
      this.pullRefreshing = true;
      void this.refreshForums();
    } else {
      this.pullRefreshing = false;
      this.pullDistance = 0;
    }
  }
  private onThreadRefreshChange(): void {
    if (this.threadRefreshing) {
      this.pullRefreshing = true;
      void this.refreshThreads();
    } else {
      this.pullRefreshing = false;
      this.pullDistance = 0;
    }
  }
  private onUserRefreshChange(): void {
    if (this.userRefreshing) {
      this.pullRefreshing = true;
      void this.refreshUsers();
    } else {
      this.pullRefreshing = false;
      this.pullDistance = 0;
    }
  }

  private async refreshForumSearch(): Promise<void> {
    try { await this.searchThreads(); } catch (e) { console.error('TiebaLite: refresh error=' + String(e)); }
    this.fsRefreshing = false;
  }

  private async refreshForums(): Promise<void> {
    try { await this.searchForums(); } catch (e) { console.error('TiebaLite: refresh error=' + String(e)); }
    this.forumRefreshing = false;
  }

  private async refreshThreads(): Promise<void> {
    try { await this.searchThreads(); } catch (e) { console.error('TiebaLite: refresh error=' + String(e)); }
    this.threadRefreshing = false;
  }

  private async refreshUsers(): Promise<void> {
    try { await this.searchUsers(); } catch (e) { console.error('TiebaLite: refresh error=' + String(e)); }
    this.userRefreshing = false;
  }

  aboutToAppear(): void {
    try { this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE); } catch (e) {}
    this.bgColor = pageBg(this.isDark);
    const params = router.getParams() as Record<string, string>;
    if (params?.forumName) {
      this.forumName = params.forumName;
    }
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, this.bgColor)
    this.onGripSideChanged();
    if (params?.keyword) {
      this.keyword = params.keyword;
      this.doSearch();
    } else {
      this.loadHistory();
    }
  }

onIsDarkChange(): void {
    this.bgColor = pageBg(this.isDark);
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, this.bgColor);
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

  onPageShow(): void {
    AppStorage.SetOrCreate('previewActiveId', '');
    AppStorage.SetOrCreate('previewActiveVisible', false);
    const t = AppStorage.get<number>('previewClaimTick') || 0;
    AppStorage.SetOrCreate<number>('previewClaimTick', t + 1);
    this.reduceEffects = AppStorage.get<boolean>('reduceEffects') === true;
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, this.bgColor)
    this.loadHistory();
    if (!this.keyword) this.showResults = false;
  }

  async loadHistory(): Promise<void> {
    try {
      this.searchHistory = await this.repo.getSearchHistory();
    } catch (e) {
      console.error('TiebaLite: loadHistory error=' + String(e));
    }
  }

  private async fetchSuggestions(kw: string): Promise<void> {
    if (!kw.trim() || this.showResults) { this.showSuggestions = false; return; }
    try {
      const data = await this.repo.getSuggestions(kw);
      const d = (data.data as Dict) || data;
      const list = (d.suggestion_list || d.suggestion || d.list || []) as string[];
      if (Array.isArray(list) && list.length > 0) {
        this.suggestions = list;
        this.showSuggestions = true;
      } else {
        this.showSuggestions = false;
      }
    } catch (e) {
      this.showSuggestions = false;
    }
  }

  private getWinWidth(): number {
    return 360;
  }

  private updateIndicatorOffset(): void {
    const totalTabs = 3;
    const contentWidth = this.tabBarWidth > 0 ? this.tabBarWidth : (this.getWinWidth() - 32);
    const tabWidth = contentWidth / totalTabs;
    const clamped = Math.max(0, Math.min(this.tabProgress, totalTabs - 1));
    const fraction = clamped - Math.floor(clamped);
    const factor = 1 - Math.abs(fraction - 0.5) * 2;
    const staticWidth = Math.round(tabWidth * 0.35);
    this.indicatorWidth = staticWidth + staticWidth * 2 * factor;
    this.tabIndicatorOffset = 16 + tabWidth * clamped + tabWidth / 2 - this.indicatorWidth / 2;
  }

  @Builder
  fsSearchContent() {
    Scroll(this.scrollers[0]) {
      Column() {
        Blank().height(this.searchBarVisible ? 106 : 46)
        ForEach(this.threadResults, (item: Dict, idx: number) => {
          Divider().height(1).color(dividerColor(this.isDark)).margin({ left: 12 })
          ThreadCard({
            thread: this.normalizeSearchThread(item),
            onCardClick: (): void => {
              NavigationHelper.navigate('pages/thread/ThreadPage', {
                threadId: getStr(item, 'tid', 'id', 'thread_id', 'threadId'),
                forumName: getStr(item, 'fname', 'forum_name', 'forumName')
              });
            },
            onLikeClick: (liked: boolean): void => {
              const tid = getStr(item, 'tid', 'id', 'thread_id', 'threadId');
              if (tid) {

                const repo = PbPageRepository.getInstance();

                if (liked) repo.likePost(Number(tid), 0).catch(() => {});

                else repo.dislikePost(Number(tid), 0).catch(() => {});

              }
            }
          }).margin({ left: 16, right: 16 })
          .transition(TransitionEffect.opacity(0).combine(TransitionEffect.translate({ x: 0, y: 20 })))
        })
        Row() {
          if (this.searchLoadingMore) {
            if (this.reduceEffects) {
              GearLoading({ gearSize: 24, color: darkenColor(this.primaryColor, 0.2), text: '加载中...' })
            }
          } else if (this.searchHasMore) {
            Text('上拉加载更多').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark))
              .onClick(() => { void this.loadMoreThreads(); })
          } else {
            Text('没有更多了').fontFamily(this.appFontFamily).fontSize(Math.round(13 * this.fontScale)).fontColor(textTertiary(this.isDark))
          }
        }
        .width('100%').justifyContent(FlexAlign.Center).padding(16)
      }
      .width('100%').padding({ bottom: 8 }).justifyContent(FlexAlign.Start)
    }
      .scrollBar(BarState.Off)
    .width('100%').height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .edgeEffect(EdgeEffect.None)
    .onDidScroll(() => { this.onSearchScroll(0); })
    .onReachEnd(() => { void this.loadMoreThreads(); })
  }

  @Builder
  forumListContent() {
    List({ scroller: this.scrollers[1] }) {
      ListItem() {
        Column() {
          Blank().height(this.searchBarVisible ? 104 : 44)
        }
        .width('100%')
      }
      ForEach(this.forumResults, (item: Dict) => {
        ListItem() {
          Row() {
            Avatar({ portrait: this.resolveSearchAvatar(getStr(item, 'avatar', 'forum_avatar', 'portrait', 'forumAvatar', 'forum_avatar_url')), avatarSize: 44, defaultName: getStr(item, 'name', 'forum_name', 'forumName', 'fname') })
            Column() {
              Text(getStr(item, 'name', 'forum_name', 'forumName', 'fname')).fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontWeight(FontWeight.Medium)
              Text(getStr(item, 'desc', 'slogan', 'introduce', 'description', 'abstract')).fontFamily(this.appFontFamily).fontSize(Math.round(13 * this.fontScale)).fontColor(textTertiary(this.isDark)).margin({ top: 2 })
            }
            .margin({ left: 12 }).layoutWeight(1)
            Image($r('app.media.ic_arrow_back')).width(18).height(18).fillColor(textTertiary(this.isDark)).rotate({ angle: 180 })
          }
          .width('100%').padding(12)
          .onClick(() => {
            NavigationHelper.navigate('pages/forum/ForumPage', { forumName: getStr(item, 'name', 'forum_name', 'forumName', 'fname'), forumId: getStr(item, 'id', 'forum_id', 'forumId') });
          })
        }
      })
    }
    .width('100%').height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .divider({ strokeWidth: 1, color: dividerColor(this.isDark) })
    .edgeEffect(EdgeEffect.None)
    .onDidScroll(() => { this.onSearchScroll(1); })
  }

  @Builder
  threadListContent() {
    List({ scroller: this.scrollers[2] }) {
      ListItem() {
        Column() {
          Blank().height(this.searchBarVisible ? 104 : 44)
        }
        .width('100%')
      }
      ForEach(this.threadResults, (item: Dict) => {
        ListItem() {
          ThreadCard({
            thread: this.normalizeSearchThread(item),
            onCardClick: (): void => {
              NavigationHelper.navigate('pages/thread/ThreadPage', {
                threadId: getStr(item, 'tid', 'id', 'thread_id', 'threadId'),
                forumName: getStr(item, 'fname', 'forum_name', 'forumName')
              });
            },
            onLikeClick: (liked: boolean): void => {
              const tid = getStr(item, 'tid', 'id', 'thread_id', 'threadId');
              if (tid) {

                const repo = PbPageRepository.getInstance();

                if (liked) repo.likePost(Number(tid), 0).catch(() => {});

                else repo.dislikePost(Number(tid), 0).catch(() => {});

              }
            }
          }).margin({ left: 16, right: 16 })
        }
      })
      ListItem() {
        Row() {
          if (this.searchLoadingMore) {
            if (this.reduceEffects) {
              GearLoading({ gearSize: 24, color: darkenColor(this.primaryColor, 0.2), text: '加载中...' })
            }
          } else if (this.searchHasMore) {
            Text('上拉加载更多').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark))
              .onClick(() => { void this.loadMoreThreads(); })
          } else {
            Text('没有更多了').fontFamily(this.appFontFamily).fontSize(Math.round(13 * this.fontScale)).fontColor(textTertiary(this.isDark))
          }
        }
        .width('100%').justifyContent(FlexAlign.Center).padding(16)
      }
    }
    .width('100%').height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .divider({ strokeWidth: 1, color: dividerColor(this.isDark) })
    .edgeEffect(EdgeEffect.None)
    .onDidScroll(() => { this.onSearchScroll(2); })
    .onReachEnd(() => { void this.loadMoreThreads(); })
  }

  @Builder
  userListContent() {
    List({ scroller: this.scrollers[3] }) {
      ListItem() {
        Column() {
          Blank().height(this.searchBarVisible ? 104 : 44)
        }
        .width('100%')
      }
      ForEach(this.userResults, (item: Dict) => {
        ListItem() {
          Row() {
            Avatar({ portrait: this.resolveSearchAvatar(getStr(item, 'portrait', 'avatar', 'icon', 'user_portrait', 'portrait_url')), avatarSize: 44, defaultName: getStr(item, 'name', 'user_name', 'nickname', 'username', 'un') })
            Column() {
              Text(getStr(item, 'name', 'name_show', 'nickname', 'user_name', 'username', 'un')).fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontWeight(FontWeight.Medium)
              Text(getStr(item, 'intro', 'desc', 'abstract', 'introduce', 'slogan', 'nickname')).fontFamily(this.appFontFamily).fontSize(Math.round(13 * this.fontScale)).fontColor(textTertiary(this.isDark)).margin({ top: 2 }).maxLines(1)
            }
            .margin({ left: 12 }).layoutWeight(1)
            Image($r('app.media.ic_arrow_back')).width(18).height(18).fillColor(textTertiary(this.isDark)).rotate({ angle: 180 })
          }
          .width('100%').padding(12)
          .onClick(() => {
            NavigationHelper.navigate('pages/user/UserProfilePage', { uid: getStr(item, 'id', 'user_id', 'uid', 'userId') });
          })
        }
      })
    }
    .width('100%').height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .divider({ strokeWidth: 1, color: dividerColor(this.isDark) })
    .edgeEffect(EdgeEffect.None)
    .onDidScroll(() => { this.onSearchScroll(3); })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%').height('100%')
        .backgroundColor(this.bgColor)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      Column() {
        if (this.isForumSearch && this.threadResults.length > 0) {
          if (this.reduceEffects) {
            Column() {
              PullToRefresh({
                reduceEffects: true,
                scroller: this.scrollers[0],
                isRefreshing: this.fsRefreshing,
                onRefresh: (): void => { this.fsRefreshing = true; },
                onTimeout: (): void => { this.fsRefreshing = false; }
              }) {
                this.fsSearchContent()
              }
            }
            .width('100%').layoutWeight(1)
          } else {
            Column() {
              PullToRefresh({
                scroller: this.scrollers[0],
                isRefreshing: this.fsRefreshing,
                onRefresh: (): void => { this.fsRefreshing = true; },
                onTimeout: (): void => { this.fsRefreshing = false; }
              }) {
                this.fsSearchContent()
              }
            }
            .width('100%').layoutWeight(1)
          }
        } else if (this.isForumSearch) {
          Text('未找到结果').fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontColor(textTertiary(this.isDark))
            .width('100%').textAlign(TextAlign.Center).padding(32)
        } else {
          Swiper() {
            Stack() {
              if (this.searching) {
                Text('搜索中...').fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontColor(textTertiary(this.isDark))
                  .width('100%').textAlign(TextAlign.Center).padding(32)
              } else if (this.showResults) {
                if (this.forumResults.length > 0) {
                  if (this.reduceEffects) {
                    PullToRefresh({
                      reduceEffects: true,
                      scroller: this.scrollers[1],
                      isRefreshing: this.forumRefreshing,
                      onRefresh: (): void => { this.forumRefreshing = true; },
                      onTimeout: (): void => { this.forumRefreshing = false; }
                    }) {
                      this.forumListContent()
                    }
                  } else {
                    PullToRefresh({
                      scroller: this.scrollers[1],
                      isRefreshing: this.forumRefreshing,
                      onRefresh: (): void => { this.forumRefreshing = true; },
                      onTimeout: (): void => { this.forumRefreshing = false; }
                    }) {
                      this.forumListContent()
                    }
                  }
                } else {
                  Text('未找到结果').fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontColor(textTertiary(this.isDark))
                    .width('100%').textAlign(TextAlign.Center).padding(32)
                }
              } else {
                this.historyContent()
              }
            }.width('100%').height('100%')

            Stack() {
              if (this.searching) {
                Text('搜索中...').fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontColor(textTertiary(this.isDark))
                  .width('100%').textAlign(TextAlign.Center).padding(32)
              } else if (this.showResults) {
                if (this.threadResults.length > 0) {
                  if (this.reduceEffects) {
                    PullToRefresh({
                      reduceEffects: true,
                      scroller: this.scrollers[2],
                      isRefreshing: this.threadRefreshing,
                      onRefresh: (): void => { this.threadRefreshing = true; },
                      onTimeout: (): void => { this.threadRefreshing = false; }
                    }) {
                      this.threadListContent()
                    }
                  } else {
                    PullToRefresh({
                      scroller: this.scrollers[2],
                      isRefreshing: this.threadRefreshing,
                      onRefresh: (): void => { this.threadRefreshing = true; },
                      onTimeout: (): void => { this.threadRefreshing = false; }
                    }) {
                      this.threadListContent()
                    }
                  }
                } else {
                  Text('未找到结果').fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontColor(textTertiary(this.isDark))
                    .width('100%').textAlign(TextAlign.Center).padding(32)
                }
              } else {
                this.historyContent()
              }
            }.width('100%').height('100%')

            Stack() {
              if (this.searching) {
                Text('搜索中...').fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontColor(textTertiary(this.isDark))
                  .width('100%').textAlign(TextAlign.Center).padding(32)
              } else if (this.showResults) {
                if (this.userResults.length > 0) {
                  if (this.reduceEffects) {
                    PullToRefresh({
                      reduceEffects: true,
                      scroller: this.scrollers[3],
                      isRefreshing: this.userRefreshing,
                      onRefresh: (): void => { this.userRefreshing = true; },
                      onTimeout: (): void => { this.userRefreshing = false; }
                    }) {
                      this.userListContent()
                    }
                  } else {
                    PullToRefresh({
                      scroller: this.scrollers[3],
                      isRefreshing: this.userRefreshing,
                      onRefresh: (): void => { this.userRefreshing = true; },
                      onTimeout: (): void => { this.userRefreshing = false; }
                    }) {
                      this.userListContent()
                    }
                  }
                } else {
                  Text('未找到结果').fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontColor(textTertiary(this.isDark))
                    .width('100%').textAlign(TextAlign.Center).padding(32)
                }
              } else {
                this.historyContent()
              }
            }.width('100%').height('100%')
          }
          .loop(false).index(this.selectedTab)
          .indicator(this.showSwiperDots)
          .onChange((idx: number) => {
            this.selectedTab = idx;
            if (this.showResults) this.loadTabData(idx);
          })
          .onAnimationStart((_index: number, targetIndex: number, _extraInfo: SwiperAnimationEvent) => {
            animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
              this.tabProgress = targetIndex;
              this.updateIndicatorOffset();
            });
          })
          .onGestureSwipe((index: number, extraInfo: SwiperAnimationEvent) => {
            const pageWidth = this.getWinWidth();
            const raw = index + (-extraInfo.currentOffset) / pageWidth;
            this.tabProgress = Math.max(0, Math.min(raw, 2));
            this.updateIndicatorOffset();
          })
          .width('100%').layoutWeight(1).clip(false)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
        }
      }
      .width('100%').height('100%').justifyContent(FlexAlign.Start)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      Column() {
        Row() {
          Image($r('app.media.ic_arrow_back')).width(22).height(22).fillColor(textPrimary(this.isDark))
            .onClick(() => router.back())
          TextInput({ text: this.keyword, placeholder: this.forumName ? '搜索 ' + this.forumName : '搜索...' })
            .layoutWeight(1)
            .height(36)
            .backgroundColor(pageBg(this.isDark))
            .borderRadius(Math.max(0, Math.round(18 * this.searchBoxRound / 100)))
            .padding({ left: 12 })
            .margin({ left: 8, right: 8 })
            .defaultFocus(true)
            .fontColor(textPrimary(this.isDark))
            .placeholderColor(textTertiary(this.isDark))
            .onChange((v: string) => {
              this.keyword = v;
              if (!v) { this.showResults = false; this.searching = false; }
              if (this.suggestionTimeoutId !== -1) { clearTimeout(this.suggestionTimeoutId); }
              this.suggestionTimeoutId = setTimeout(() => { this.fetchSuggestions(v); }, 300);
            })
            .onSubmit(() => this.doSearch())
          Button('搜索')
            .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor('#FFFFFF')
            .backgroundColor(this.primaryColor)
            .borderRadius(Math.max(0, Math.round(18 * this.searchBoxRound / 100)))
            .height(36)
            .onClick(() => this.doSearch())
        }
        .padding(this.searchBarVisible ? 12 : 0)
        .width('100%')
        .height(this.searchBarVisible ? 60 : 0)
        .clip(true)
        .animation({ duration: 200, curve: Curve.FastOutSlowIn })

        if (this.isForumSearch) {
          Row() {
            Row() {
              Text(this.selectedScope === 0 ? '全部帖子' : '帖子')
                .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textPrimary(this.isDark))
              Text('▾').fontFamily(this.appFontFamily).fontSize(10).fontColor(textSecondary(this.isDark)).margin({ left: 4 })
            }
            .height(36).padding({ left: 12, right: 12 })
            .backgroundColor(pageBg(this.isDark)).borderRadius(18)
            .onClick(() => { this.showScopeDD = !this.showScopeDD; this.showSortDD = false; })
            .onTouch((e: TouchEvent) => { if (e.type === TouchType.Down && !this.showScopeDD) { this.showScopeDD = true; this.showSortDD = false; } })

            Blank()

            Row() {
              Text(this.sortMode === 2 ? '相关度' : '最新回复')
                .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textPrimary(this.isDark))
              Text('▾').fontFamily(this.appFontFamily).fontSize(10).fontColor(textSecondary(this.isDark)).margin({ left: 4 })
            }
            .height(36).padding({ left: 12, right: 12 })
            .backgroundColor(pageBg(this.isDark)).borderRadius(18)
            .onClick(() => { this.showSortDD = !this.showSortDD; this.showScopeDD = false; })
            .onTouch((e: TouchEvent) => { if (e.type === TouchType.Down && !this.showSortDD) { this.showSortDD = true; this.showScopeDD = false; } })
          }
          .width('100%').padding({ left: 12, right: 12, top: 6, bottom: 4 })
        } else {
          Stack() {
            Row() {
              ForEach(['贴吧', '帖子', '用户'], (tab: string, idx: number) => {
                Column() {
                  Text(tab)
                    .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale))
                    .fontColor(idx === this.selectedTab ? textAccent(this.primaryColor, this.isDark) : textSecondary(this.isDark))
                    .fontWeight(idx === this.selectedTab ? FontWeight.Bold : FontWeight.Regular)
                    .padding(12)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)
                .onClick(() => {
                  this.switchTab(idx);
                  this.showSuggestions = false;
                })
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
      }
      .position({ x: 0, y: 0 })
      .zIndex(2)
      .width('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
      .backgroundColor(this.cardStyle === 1 ? withAlpha(darkenColor(this.bgColor, this.headerTint / 100), 1 - this.headerAlpha / 100) : withAlpha(this.bgColor, 1 - this.headerAlpha / 100))
      .backdropBlur(60)
      .border({ width: { bottom: 1 }, color: this.isForumSearch ? blendWithBg(this.primaryColor, 0.15, this.isDark, '#1E1E1E') : dividerColor(this.isDark) })

      if (this.searchLoadingMore) {
        Column() {
          GearCycle({ gearSize: 40, color: darkenColor(this.primaryColor, 0.2), refreshing: true })
        }
        .width('100%')
        .position({ bottom: 90, left: 0, right: 0 })
        .zIndex(10)
      }

      if (this.showSuggestions) {
        Column().width('100%').height('100%').onClick(() => { this.showSuggestions = false; })
      }
      if (this.showSuggestions && this.suggestions.length > 0) {
        Column() {
          ForEach(this.suggestions, (item: string) => {
            Row() {
              Image($r('app.media.ic_search')).width(Math.round(16 * this.fontScale)).height(Math.round(16 * this.fontScale)).fillColor(textTertiary(this.isDark)).margin({ right: 12 })
              Text(item).fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textPrimary(this.isDark))
            }
            .width('100%').padding({ left: 24, top: 12, bottom: 12 })
            .onClick(() => {
              this.keyword = item;
              this.showSuggestions = false;
              this.doSearch();
            })
          })
        }
        .width('100%')
        .backgroundColor(this.bgColor)
        .borderRadius(14)
        .shadow({ radius: 8, color: shadowColor(this.isDark), offsetY: 2 })
        .position({ top: 60, left: 0, right: 0 })
      }
      if (this.showScopeDD) {
        Column().width('100%').height('100%').onClick(() => { this.showScopeDD = false; }).zIndex(3)
      }
      if (this.showSortDD) {
        Column().width('100%').height('100%').onClick(() => { this.showSortDD = false; }).zIndex(3)
      }
      if (this.showScopeDD) {
        Column() {
          Row() {
            Text('').width(0)
            Column() {
              ForEach(['全部帖子', '帖子'], (opt: string, idx: number) => {
                Text(opt).fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale))
                  .fontColor(this.selectedScope === idx ? textAccent(this.primaryColor, this.isDark) : textPrimary(this.isDark))
                  .fontWeight(this.selectedScope === idx ? FontWeight.Bold : FontWeight.Regular)
                  .padding(12).width('100%')
                  .onClick(() => {
                    this.selectedScope = idx;
                    this.showScopeDD = false;
                    if (this.showResults) this.doSearch();
                  })
              })
            }
            .width(120).backgroundColor(this.bgColor).borderRadius(8).shadow({ radius: 6, color: shadowColor(this.isDark), offsetY: 2 })
          }
        }
        .width('100%').position({ top: 106, left: 0, right: 0 }).padding({ left: 12, top: 2, bottom: 4 }).zIndex(3)
      }
      if (this.showSortDD) {
        Column() {
          Row() {
            Text('').width(0)
            Column() {
              ForEach(['相关度', '最新回复'], (opt: string, idx: number) => {
                Text(opt).fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale))
                  .fontColor(this.sortMode === (idx === 0 ? 2 : 1) ? textAccent(this.primaryColor, this.isDark) : textPrimary(this.isDark))
                  .fontWeight(this.sortMode === (idx === 0 ? 2 : 1) ? FontWeight.Bold : FontWeight.Regular)
                  .padding(12).width('100%')
                  .onClick(() => {
                    this.sortMode = (idx === 0 ? 2 : 1);
                    this.showSortDD = false;
                    if (this.showResults) this.doSearch();
                  })
              })
            }
            .width(130).backgroundColor(this.bgColor).borderRadius(8).shadow({ radius: 6, color: shadowColor(this.isDark), offsetY: 2 })
          }
        }
        .width('100%').position({ top: 106, left: 0, right: 0 }).padding({ left: 12, top: 2, bottom: 4 }).zIndex(3)
      }

      if (this.scrollTop > 500) {
        Image($r('app.media.ic_arrow_up')).width(Math.round(22 * this.fontScale)).height(Math.round(22 * this.fontScale))
          .fillColor(onPrimaryContainer(this.isDark))
          .width(44).height(44).borderRadius(22 * this.fabRadius / 100)
          .backgroundColor(primaryContainer(this.isDark))
          .shadow({ radius: 6, color: shadowColor(this.isDark), offsetY: 3 })
          .position({ bottom: 64, right: 16 })
          .translate({ x: this.showScrollTop ? (this.fabLeft ? -(this.getWinWidth() - 76) : 0) : (this.fabLeft ? -(this.getWinWidth() - 76) - 60 : 60) })
          .onClick(() => this.scrollResultsToTop())
      }
    }
    .width('100%').height('100%')
    .onTouch((event: TouchEvent) => {
      if (!GripDetector.isEnabled() || GripDetector.isNativeAvailable()) return;
      const side = GripDetector.touchSide(event.touches);
      if (side === -1 && this.fabLeft) {
        this.switchFabSide(false);
      } else if (side === 1 && !this.fabLeft) {
        this.switchFabSide(true);
      }
    })
    
  }

  private normalizeSearchThread(item: Dict): Dict {
    const rawUser = item.user as Dict;
    const rawAuthor = item.author;
    let authorName = '';
    let authorPortrait = '';
    let authorId = '';
    if (rawUser) {
      authorName = getStr(rawUser, 'user_name', 'show_nickname', 'name', 'name_show', 'nickname');
      authorPortrait = getStr(rawUser, 'portrait', 'avatar', 'user_portrait');
      authorId = getStr(rawUser, 'user_id', 'uid', 'id');
    }
    if (typeof rawAuthor === 'string') {
      authorName = rawAuthor;
    } else if (rawAuthor) {
      authorName = getStr(rawAuthor as Dict, 'name', 'name_show', 'nickname');
      authorPortrait = getStr(rawAuthor as Dict, 'portrait', 'avatar', 'user_portrait');
      authorId = getStr(rawAuthor as Dict, 'id', 'user_id', 'uid');
    }
    if (!authorId) authorId = getStr(item, 'author_id', 'userId', 'user_id', 'uid', 'authorUid');
    if (authorId && (!authorName || !authorPortrait)) {
      for (const u of this.userList) {
        const uid = getStr(u, 'id', 'user_id', 'uid');
        if (uid === authorId) {
          if (!authorName) authorName = getStr(u, 'name', 'name_show', 'nickname', 'userName', 'user_name', 'showName', 'show_name');
          if (!authorPortrait) authorPortrait = getStr(u, 'portrait', 'user_portrait', 'avatar', 'icon');
          break;
        }
      }
    }
    if (!authorName) authorName = getStr(item, 'authorName', 'author_name', 'username', 'user_name', 'un', 'nickname');
    const rawPortrait = item.author_portrait || item.authorPortrait;
    if (typeof rawPortrait === 'string') authorPortrait = rawPortrait;
    if (!authorPortrait) authorPortrait = getStr(item, 'portrait', 'avatar', 'user_portrait', 'portrait_url');
    authorPortrait = this.resolveSearchAvatar(authorPortrait);
    const lastTime = getStr(item, 'last_time', 'lastTime', 'time', 'post_time', 'create_time', 'createTime', 'timestamp');
    const forumName = getStr(item, 'fname', 'forum_name', 'forumName');
    const title = item.title || '';
    const mediaArr = item.media as Dict[] || [];
    const imageUrls = item.imageUrls as string[] || [];
    return {
      id: item.tid || item.id || item.thread_id,
      tid: item.tid || item.id || item.thread_id,
      title: title,
      author: { name: authorName, portrait: authorPortrait, id: authorId, name_show: authorName },
      authorName: authorName,
      authorPortrait: authorPortrait,
      author_id: authorId,
      lastTime: lastTime,
      replyNum: getNum(item, 'post_num', 'reply_num', 'replyNum', 'comment_num', 'commentNum'),
      agreeNum: getNum(item, 'agree_num', 'agreeNum', 'like_num', 'likeNum'),
      abstract: getStr(item, 'abstract', 'abstractText', 'excerpt', 'content', 'firstPostContent'),
      forumName: forumName,
      forumId: getStr(item, 'forum_id', 'fid', 'forumId'),
      media: mediaArr,
      imageUrls: imageUrls,
      firstPostContent: item.firstPostContent || item.first_post_content || item._abstract || item.abstract
    };
  }

  private resolveSearchAvatar(portrait: string): string {
    if (!portrait) return '';
    if (portrait.startsWith('http://') || portrait.startsWith('https://')) return portrait;
    return 'http://tb.himg.baidu.com/sys/portraitn/item/' + portrait;
  }

  private async doSearch(): Promise<void> {
    if (!this.keyword.trim()) return;
    this.showSuggestions = false;
    this.searching = true;
    this.showSortPopup = false;
    this.threadResults = [];
    this.forumResults = [];
    this.userResults = [];
    this.userList = [];
    try {
      await this.repo.saveSearchHistory(this.keyword);
      if (this.isForumSearch) {
        await this.searchThreads();
      } else {
        await Promise.all([
          this.searchForums(),
          this.searchThreads(),
          this.searchUsers()
        ]);
      }
    } catch (e) {
      console.error('TiebaLite: search error=' + String(e));
      this.threadResults = [];
      this.forumResults = [];
      this.userResults = [];
    }
    this.searching = false;
    this.showResults = true;
    this.loadHistory();
    this.refreshKey++;
  }

  private async searchThreads(): Promise<void> {
    this.searchPage = 1;
    this.searchHasMore = true;
    try {
      let data: Dict;
      if (this.forumName) {
        data = await this.repo.searchThread(this.keyword, 1, this.sortMode, this.forumName, this.selectedScope);
      } else {
        data = await this.repo.searchThread(this.keyword, 1, this.sortMode);
      }
      const d = (data.data as Dict) || data;
      const list = (d.thread_list || d.post_list || d.list || d.data_list || d.data || d.result || d.items || d.feed || []) as Dict[];
      if (list.length > 0) { this.threadResults = list; }
      const ul = d.user_list;
      if (ul && Array.isArray(ul)) this.userList = ul as Dict[];
    } catch (e) {
      console.error('TiebaLite: searchThreads error=' + String(e));
    }
  }

  private async loadMoreThreads(): Promise<void> {
    if (this.searchLoadingMore || !this.searchHasMore || this.searching) return;
    this.searchLoadingMore = true;
    try {
      const nextPage = this.searchPage + 1;
      let data: Dict;
      if (this.forumName) {
        data = await this.repo.searchThread(this.keyword, nextPage, this.sortMode, this.forumName, this.selectedScope);
      } else {
        data = await this.repo.searchThread(this.keyword, nextPage, this.sortMode);
      }
      const d = (data.data as Dict) || data;
      const list = (d.thread_list || d.post_list || d.list || d.data_list || d.data || d.result || d.items || d.feed || []) as Dict[];
      if (list.length === 0) {
        this.searchHasMore = false;
      } else {
        this.threadResults = [...this.threadResults, ...list];
        this.searchPage = nextPage;
      }
    } catch (e) {
      this.searchHasMore = false;
      console.error('TiebaLite: loadMoreThreads error=' + String(e));
    } finally {
      this.searchLoadingMore = false;
    }
  }

  private async searchForums(): Promise<void> {
    try {
      const data = await this.repo.searchForum(this.keyword);
      const d = (data.data as Dict) || data;
      const list = (d.forum_list || d.list || d.data_list || d.data || d.result || d.forum || d.forums || []) as Dict[];
      if (list.length > 0) { this.forumResults = list; }
    } catch (e) {
      console.error('TiebaLite: searchForums error=' + String(e));
    }
  }

  private async searchUsers(): Promise<void> {
    try {
      const data = await this.repo.searchUser(this.keyword);
      const d = (data.data as Dict) || data;
      const list = (d.user_list || d.list || d.data_list || d.data || d.result || d.user || d.users || []) as Dict[];
      if (list.length > 0) { this.userResults = list; }
    } catch (e) {
      console.error('TiebaLite: searchUsers error=' + String(e));
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

