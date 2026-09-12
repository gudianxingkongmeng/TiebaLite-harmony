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
import { getStr, blendWithBg, pageBg, cardBg, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../../core/utils/DataHelper';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';

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
  @State scrollTop: number = 0;
  private scroller: Scroller = new Scroller();

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
      .padding(12).width('100%').backgroundColor(pageBg(this.isDark))

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
          Scroll(this.scroller) {
            Column() {
              ForEach(this.items, (item: Dict, index: number) => {
                Column() {
                  ThreadCard({
                    thread: item,
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
                  Row() {
                    Blank()
                    Row() {
                      Image($r('app.media.ic_close')).width(14).height(14).fillColor(textTertiary(this.isDark))
                      Text('删除').fontFamily(this.appFontFamily).fontSize(12).fontColor(textTertiary(this.isDark)).margin({ left: 4 })
                    }
                      .onClick(async () => {
                        await HistoryRepository.getInstance().deleteThreadHistory(item.id as number);
                        this.items = this.items.filter((i: Dict) => i.id !== item.id);
                      })
                  }
                  .padding({ right: 12, bottom: 6 })
                  .width('100%')
                }
              })
            }
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