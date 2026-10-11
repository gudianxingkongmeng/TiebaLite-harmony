import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import window from '@ohos.window';
import display from '@ohos.display';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import HistoryRepository from '../../core/repository/HistoryRepository';
import { ThreadHistoryEntity } from '../../core/storage/DatabaseManager';
import PbPageRepository from '../../core/repository/PbPageRepository';
import ThreadCard from '../../components/ThreadCard';
import GearLoading from '../../components/GearLoading';
import GearCycle from '../../components/GearCycle';
import PullToRefresh from '../../components/PullToRefresh';
import BackToTopButton from '../../components/BackToTopButton';
import { Dict } from '../../core/types/Dict';
import { getStr, blendWithBg, pageBg, cardBg, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor, withAlpha, glassTopBarSurface, glassTopBarEffect, glassBlurLevel } from '../../core/utils/DataHelper';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';

class HistoryDataSource implements IDataSource {
  private listeners: DataChangeListener[] = [];
  private items: Dict[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): Dict {
    return this.items[index];
  }

  getDataId(index: number): string {
    return String(this.items[index].id ?? index);
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const idx = this.listeners.indexOf(listener);
    if (idx >= 0) {
      this.listeners.splice(idx, 1);
    }
  }

  resetData(newItems: Dict[]): void {
    this.items = newItems;
    this.listeners.forEach((l: DataChangeListener) => { l.onDataReloaded(); });
  }

  removeById(id: number): void {
    const idx = this.items.findIndex((i: Dict) => Number(i.id) === id);
    if (idx >= 0) {
      this.items.splice(idx, 1);
      this.listeners.forEach((l: DataChangeListener) => { l.onDataDeleted(idx); });
    }
  }
}

@Entry
@Component
struct HistoryPage {
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  reduceEffects: boolean = false;
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @State items: Dict[] = [];
  @State loading: boolean = true;
  @State @Watch('onRefreshStateChange') isRefreshing: boolean = false;
  @State pullDistance: number = 0;
  @State pullRefreshing: boolean = false;
  @State topInset: number = 24;
  @StorageLink('headerAlpha') headerAlpha: number = 25;
  @State scrollTop: number = 0;
  private scroller: Scroller = new Scroller();
  private dataSource: HistoryDataSource = new HistoryDataSource();

  aboutToAppear(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
    this.load();
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
    await this.load();
    this.isRefreshing = false;
  }

  async load(): Promise<void> {
    this.loading = true;
    try {
      const raw = await HistoryRepository.getInstance().getThreadHistories();
      this.items = raw.map((h: ThreadHistoryEntity) => this.toThreadDict(h));
      this.dataSource.resetData(this.items);
    } catch (e) {}
    this.loading = false;
  }

  private toThreadDict(h: ThreadHistoryEntity): Dict {
    const result: Dict = {
      id: h.id,
      tid: h.id,
      title: h.title || '',
      authorName: h.name || '',
      authorPortrait: h.avatar || '',
      forumName: h.forum || '',
      lastTimeInt: h.timestamp ? String(Math.floor(h.timestamp)) : '',
      replyNum: 0,
      author: {
        name: h.name || '',
        portrait: h.avatar || ''
      }
    };
    if (h.data) {
      try {
        const extra = JSON.parse(h.data) as Dict;
        for (const k of Object.keys(extra)) {
          if (result[k] === undefined || result[k] === '' || result[k] === 0) {
            result[k] = extra[k];
          }
        }
      } catch (_) {}
    }
    return result;
  }

  @Builder
  gearRefreshHeader() {
    if (this.reduceEffects) {
      Row() {
        GearLoading({ gearSize: 20, color: textTertiary(this.isDark), text: this.isRefreshing ? '刷新中...' : '下拉刷新' })
      }
      .width('100%').padding({ top: 12, bottom: 12 })
      .justifyContent(FlexAlign.Center)
    } else {
      Column().height(0)
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
          Image($r('app.media.ic_arrow_back')).width(22).height(22).fillColor(textPrimary(this.isDark)).onClick(() => router.back())
          Text('浏览历史').fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold).margin({ left: 16 })
        Blank()
        Text('清除').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark))
          .onClick(async () => {
            await HistoryRepository.getInstance().clearThreadHistories();
            this.items = [];
          })
      }
      .padding({ left: 12, right: 12, bottom: 12, top: 12 + this.topInset }).width('100%')
      .backgroundColor(glassTopBarSurface(pageBg(this.isDark), this.isDark, this.headerAlpha))
      .backdropBlur(glassBlurLevel(this.headerAlpha) + 14)
        .backgroundEffect(glassTopBarEffect(this.headerAlpha))
      .border({ width: { bottom: 1 }, color: dividerColor(this.isDark) })
      .position({ x: 0, y: 0 })
      .zIndex(2)

      if (this.loading) {
        Text('加载中...').fontFamily(this.appFontFamily).fontSize(16).fontColor(textTertiary(this.isDark))
          .width('100%').textAlign(TextAlign.Center).padding(48)
      } else if (this.items.length === 0) {
        Text('暂无浏览记录').fontFamily(this.appFontFamily).fontSize(16).fontColor(textTertiary(this.isDark))
          .width('100%').textAlign(TextAlign.Center).padding(48)
      } else {
        PullToRefresh({
          scroller: this.scroller,
          reduceEffects: this.reduceEffects,
          onRefresh: (): void => { this.isRefreshing = true; },
          onTimeout: (): void => { this.isRefreshing = false; }
        }) {
          List({ scroller: this.scroller }) {
            ListItem() {
              Column() {
                    Blank().height(46 + this.topInset)
              }
              .width('100%')
            }
            LazyForEach(this.dataSource, (item: Dict) => {
              ListItem() {
                Column() {
                  ThreadCard({
                    thread: item,
                    showDelete: true,
                    onDeleteClick: async (): Promise<void> => {
                      await HistoryRepository.getInstance().deleteThreadHistory(item.id as number);
                      this.items = this.items.filter((i: Dict) => i.id !== item.id);
                      this.dataSource.removeById(item.id as number);
                    },
                    onCardClick: (): void => {
                      NavigationHelper.navigate('pages/thread/ThreadPage', {
                        threadId: String(item.id || item.tid || 0),
                        forumName: String(item.forumName || item.forum || '')
                      });
                    },
                    onLikeClick: (liked: boolean): void => {
                      const tid = getStr(item, 'id', 'tid', 'threadId', 'thread_id');
                      if (tid) {
                        const repo = PbPageRepository.getInstance();
                        if (liked) repo.likePost(Number(tid), 0).catch(() => {});
                        else repo.dislikePost(Number(tid), 0).catch(() => {});
                      }
                    }
                  })
                  .margin({ left: 16, right: 16, top: 6, bottom: 6 })
                }
              }
            }, (item: Dict) => String(item.id ?? item.tid))
          }
          .scrollBar(BarState.Off)
          .onDidScroll(() => {
            this.scrollTop = this.scroller.currentOffset().yOffset;
          })
          .width('100%').layoutWeight(1)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
          .backgroundColor(pageBg(this.isDark))
          .edgeEffect(EdgeEffect.None)
        }
      }
      }
      .width('100%').height('100%').justifyContent(FlexAlign.Start)
      .backgroundColor(pageBg(this.isDark))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      BackToTopButton({
        scrollTop: $scrollTop,
        onTopClick: () => { this.scroller.scrollEdge(Edge.Top); }
      })
    }
    .width('100%').height('100%').backgroundColor(pageBg(this.isDark)).expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
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
