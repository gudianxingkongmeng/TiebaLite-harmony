import router from '@ohos.router';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import HotTopicRepository from '../../core/repository/HotTopicRepository';
import SearchRepository from '../../core/repository/SearchRepository';
import NetworkImage from '../../components/Images';
import ThreadCard from '../../components/ThreadCard';
import LoadingState from '../../components/LoadingState';
import ErrorState from '../../components/ErrorState';
import GearLoading from '../../components/GearLoading';
import { Dict } from '../../core/types/Dict';
import { getStr, blendWithWhite, darkenColor, blendWithBg, pageBg, cardBg, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../../core/utils/DataHelper';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';

@Entry
@Component
struct TopicDetailPage {
  @State topicId: string = '';
  @State topicName: string = '';

  @State topicDetail: Dict | null = null;
  @State threads: Dict[] = [];
  @State page: number = 1;
  @State hasMore: boolean = true;
  @State loading: boolean = true;
  @State loadingMore: boolean = false;
  @State error: string = '';
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  reduceEffects: boolean = false;
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';

  private topicRepo: HotTopicRepository = HotTopicRepository.getInstance();
  private searchRepo: SearchRepository = SearchRepository.getInstance();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.topicId = params?.topicId || '';
    this.topicName = params?.topicName || '';
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
    this.loadData();
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

  async loadData(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const topicData: Dict = await this.topicRepo.loadTopicList();
      const topicList: Dict[] = this.extractTopics(topicData);
      const found: Dict | undefined = topicList.find((t: Dict) =>
        String(t.topicId || t.topic_id || t.id || '') === this.topicId
      );
      this.topicDetail = found || { name: this.topicName } as Dict;

      const searchData: Dict = await this.searchRepo.searchThread(this.topicName, 1, 2);
      this.threads = ((searchData.data as Dict)?.thread_list || searchData.thread_list || []) as Dict[];
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
          Text('话题详情')
            .fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold)
            .margin({ left: 12 })
          Blank()
        }
        .padding(12)
      .width('100%')
      .backgroundColor(cardBg(this.isDark))

      if (this.loading) {
        LoadingState({ message: '加载中...' })
      } else if (this.error.length > 0) {
        ErrorState({ message: this.error, onRetryAction: (): void => { void this.loadData(); } })
      } else {
        Scroll() {
          Column() {
            if (this.topicDetail) {
              this.topicHeader(this.topicDetail)
              Divider().height(8).color(dividerColor(this.isDark)).width('100%')
            }

            if (this.threads.length === 0) {
              Text('暂无相关帖子').fontFamily(this.appFontFamily).fontSize(16).fontColor(textTertiary(this.isDark))
                .width('100%').textAlign(TextAlign.Center).padding(48)
            } else {
              ForEach(this.threads, (thread: Dict, index: number) => {
                ThreadCard({
                  thread: thread,
                  onCardClick: (): void => {
                    NavigationHelper.navigate('pages/thread/ThreadPage', {
                      threadId: String(thread.id || thread.tid || 0),
                      forumId: String(thread.forumId || 0),
                      forumName: String(thread.forumName || '')
                    });
                  }
                })
                .margin({ left: 12, right: 12, top: 6, bottom: 6 })
              })
            }

            if (this.hasMore && this.threads.length > 0) {
              Row() {
                if (this.loadingMore) {
                  GearLoading({ gearSize: 18, color: textTertiary(this.isDark), text: '加载中...' })
                } else {
                  Text('加载更多...')
                    .fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark))
                    .onClick(() => this.loadMore())
                }
              }
              .width('100%').justifyContent(FlexAlign.Center).padding(16)
            }
          }
          .width('100%')
          .padding({ bottom: 16 })
        }
          .scrollBar(BarState.Off)
        .width('100%')
        .layoutWeight(1)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
        .backgroundColor(pageBg(this.isDark))
        .edgeEffect(EdgeEffect.Spring)
        .onReachEnd(() => {
          if (this.hasMore) {
            this.page++;
            this.loadMore();
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    }
    .width('100%').height('100%')
    .backgroundColor(pageBg(this.isDark)).expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    
  }

  @Builder
  private topicHeader(topic: Dict) {
    Column() {
      if (getStr(topic, 'avatar', 'image', 'pic', 'picture', 'cover', 'img', 'head', 'icon', 'smallPic', 'small_pic', 'bigPic', 'big_pic', 'topicPic', 'topic_pic', 'topicAvatar', 'topic_avatar')) {
        NetworkImage({
          src: getStr(topic, 'avatar', 'image', 'pic', 'picture', 'cover', 'img', 'head', 'icon', 'smallPic', 'small_pic', 'bigPic', 'big_pic', 'topicPic', 'topic_pic', 'topicAvatar', 'topic_avatar'),
          imageWidth: '100%',
          imageHeight: 160,
          imageBorderRadius: 8
        })
      }

      Text(String(topic.name || topic.topicName || ''))
        .fontFamily(this.appFontFamily).fontSize(22).fontWeight(FontWeight.Bold)
        .fontColor(textPrimary(this.isDark))
        .width('100%')
        .margin({ top: 12 })

      if (topic.desc) {
        Text(String(topic.desc))
          .fontFamily(this.appFontFamily).fontSize(14).fontColor(textSecondary(this.isDark))
          .lineHeight(20)
          .width('100%')
          .margin({ top: 8 })
      }

      Row() {
        Text(String(topic.participantNum || topic.participant_num || 0) + ' 参与')
          .fontFamily(this.appFontFamily).fontSize(13).fontColor(textTertiary(this.isDark))
        Blank()
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .padding(12)
    .width('100%')
    .backgroundColor(cardBg(this.isDark))
  }

  private extractTopics(data: Dict): Dict[] {
    if (!data) return [];
    if (data.topic_list) return data.topic_list as Dict[];
    if ((data.data as Dict)?.topic_list) return (data.data as Dict).topic_list as Dict[];
    if (Array.isArray(data)) return data as Dict[];
    return [];
  }

  private async loadMore(): Promise<void> {
    if (this.loadingMore) return;
    this.loadingMore = true;
    try {
      const searchData: Dict = await this.searchRepo.searchThread(this.topicName, this.page, 2);
      const more: Dict[] = ((searchData.data as Dict)?.thread_list || searchData.thread_list || []) as Dict[];
      if (more.length === 0) { this.hasMore = false; return; }
      this.threads = [...this.threads, ...more];
    } catch (e) {
      this.hasMore = false;
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
