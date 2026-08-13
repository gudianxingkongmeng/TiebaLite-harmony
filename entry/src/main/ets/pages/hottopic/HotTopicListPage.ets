import router from '@ohos.router';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import HotTopicRepository from '../../core/repository/HotTopicRepository';
import NetworkImage from '../../components/Images';
import LoadingState from '../../components/LoadingState';
import ErrorState from '../../components/ErrorState';
import { Dict } from '../../core/types/Dict';
import { getStr, getNum, blendWithWhite, darkenColor, blendWithBg, pageBg, cardBg, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../../core/utils/DataHelper';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';

@Entry
@Component
struct HotTopicListPage {
  @State topics: Dict[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';

  private repo: HotTopicRepository = HotTopicRepository.getInstance();

  aboutToAppear(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
    this.loadTopics();
  }

  onIsDarkChange(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
  }

  onPageShow(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
  }

  async loadTopics(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const data: Dict = await this.repo.loadTopicList();
      this.topics = this.extractTopics(data);
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
          Text('热门话题')
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
        ErrorState({ message: this.error, onRetryAction: (): void => { void this.loadTopics(); } })
      } else if (this.topics.length === 0) {
        Text('暂无热门话题')
          .fontFamily(this.appFontFamily).fontSize(16).fontColor(textTertiary(this.isDark))
          .width('100%').textAlign(TextAlign.Center).padding(48)
      } else {
        Scroll() {
          Column() {
            ForEach(this.chunkTopics(this.topics), (pair: Dict[], rowIdx: number) => {
              Row() {
                ForEach(pair, (topic: Dict, colIdx: number) => {
                  Column() { this.topicCard(topic) }
                    .layoutWeight(1)
                    .margin({ left: colIdx === 0 ? 0 : 4, right: colIdx === 0 ? 4 : 0 })
                })
                if (pair.length === 1) {
                  Row().layoutWeight(1).margin({ left: 4 })
                }
              }
              .width('100%')
              .margin({ bottom: 8 })
            })
          }
          .padding(12)
          .width('100%')
        }
          .scrollBar(BarState.Off)
        .width('100%')
        .layoutWeight(1)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .width('100%').height('100%')
    .backgroundColor(pageBg(this.isDark)).expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    
  }

  @Builder
  private topicCard(topic: Dict) {
    Column() {
      if (getStr(topic, 'avatar', 'image', 'pic', 'picture', 'cover', 'img', 'head', 'icon', 'smallPic', 'small_pic', 'bigPic', 'big_pic', 'topicPic', 'topic_pic', 'topicAvatar', 'topic_avatar')) {
        NetworkImage({
          src: getStr(topic, 'avatar', 'image', 'pic', 'picture', 'cover', 'img', 'head', 'icon', 'smallPic', 'small_pic', 'bigPic', 'big_pic', 'topicPic', 'topic_pic', 'topicAvatar', 'topic_avatar'),
          imageWidth: '100%',
          imageHeight: 100,
          imageBorderRadius: 8
        })
      } else {
        Column()
          .width('100%')
          .height(100)
          .backgroundColor('#E0E0E0')
          .borderRadius(8)
      }

      Text(getStr(topic, 'topicName', 'topic_name', 'name', 'title'))
        .fontFamily(this.appFontFamily).fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(textPrimary(this.isDark))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 6 })

      if (getStr(topic, 'desc', 'description', 'intro', 'abstract')) {
        Text(getStr(topic, 'desc', 'description', 'intro', 'abstract'))
          .fontFamily(this.appFontFamily).fontSize(12)
          .fontColor(textTertiary(this.isDark))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 2 })
      }

      Row() {
        Text(String(getNum(topic, 'participantNum', 'participant_num', 'discussNum', 'discuss_num', 'joinNum', 'join_num')) + ' 参与')
          .fontFamily(this.appFontFamily).fontSize(11)
          .fontColor(textTertiary(this.isDark))
        Blank()
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .padding(10)
    .backgroundColor(cardBg(this.isDark))
    .borderRadius(8)
    .onClick(() => {
      NavigationHelper.navigate('pages/hottopic/TopicDetailPage', {
        topicId: String(getStr(topic, 'topicId', 'topic_id', 'id', 'tid') || ''),
        topicName: getStr(topic, 'topicName', 'topic_name', 'name', 'title')
      });
    })
  }

  private chunkTopics(arr: Dict[]): Dict[][] {
    const result: Dict[][] = [];
    for (let i = 0; i < arr.length; i += 2) {
      result.push(arr.slice(i, i + 2));
    }
    return result;
  }

  private extractTopics(data: Dict): Dict[] {
    if (!data) return [];
    const tryList = (src: Dict, keys: string[]): Dict[] | undefined => {
      if (!src) return undefined;
      for (const k of keys) {
        const v = src[k] as Dict[] | undefined;
        if (Array.isArray(v) && v.length > 0) return v;
      }
      return undefined;
    };
    const candidates = [data, data.data as Dict, (data.data as Dict)?.data as Dict];
    for (const d of candidates) {
      if (!d) continue;
      if (Array.isArray(d)) return d as Dict[];
      const r = tryList(d, ['topic_list', 'topicList', 'topics', 'topic_info', 'topicInfo']);
      if (r) return r;
      for (const bangKey of ['topic_bang', 'topicBang']) {
        const bang = d[bangKey] as Dict || {};
        const r2 = tryList(bang, ['topic_list', 'topicList']);
        if (r2) return r2;
      }
      const manual = d['topic_manual'] as Dict || {};
      const r3 = tryList(manual, ['topic_list', 'topicList']);
      if (r3) return r3;
    }
    if (Array.isArray(data)) return data as Dict[];
    return [];
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
