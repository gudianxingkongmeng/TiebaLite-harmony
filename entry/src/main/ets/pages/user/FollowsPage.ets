import router from '@ohos.router';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import Avatar from '../../components/Avatar';
import LoadingState from '../../components/LoadingState';
import ErrorState from '../../components/ErrorState';
import GearLoading from '../../components/GearLoading';
import { Dict } from '../../core/types/Dict';
import { TiebaApi } from '../../core/api/TiebaApi';
import { getNum, getStr, buildPortraitUrl, textAccent, pageBg, cardBg, textPrimary, textSecondary, textTertiary, dividerColor } from '../../core/utils/DataHelper';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';

@Entry
@Component
struct FollowsPage {
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  reduceEffects: boolean = false;
  @StorageLink('fontScale') fontScale: number = 1.0;
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @State uid: number = 0;
  @State currentTab: number = 0;
  @State followsList: Dict[] = [];
  @State fansList: Dict[] = [];
  @State followsLoading: boolean = false;
  @State fansLoading: boolean = false;
  @State followsError: string = '';
  @State fansError: string = '';
  @State followsHasMore: boolean = false;
  @State fansHasMore: boolean = false;
  @State followsPn: number = 1;
  @State fansPn: number = 1;
  @State followsLoadingMore: boolean = false;
  @State fansLoadingMore: boolean = false;
  private api = TiebaApi.getInstance();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    this.uid = parseInt(String(params?.uid || '0'));
    this.currentTab = params?.initialTab === 1 ? 1 : 0;
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
    this.loadFollows(true);
    this.loadFans(true);
  }

  onIsDarkChange(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
  }

  onPageShow(): void {
    this.reduceEffects = AppStorage.get<boolean>('reduceEffects') === true;
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
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

  private parseUserList(raw: Dict, key: string): Dict[] {
    const arr = raw[key];
    if (!Array.isArray(arr)) return [];
    return arr.map((item: Dict): Dict => ({
      id: getNum(item, 'id', 'user_id', 'uid', 'userid'),
      portrait: getStr(item, 'portrait', 'user_portrait', 'portrait_url', 'avatar'),
      name: getStr(item, 'name', 'user_name', 'username', 'un'),
      name_show: getStr(item, 'name_show', 'nickname', 'nick_name', 'nickName', 'show_name')
    }));
  }

  private async loadFollows(isRefresh: boolean): Promise<void> {
    if (isRefresh) {
      if (this.followsLoading) return;
      this.followsLoading = true;
      this.followsError = '';
      this.followsPn = 1;
    } else {
      if (this.followsLoadingMore || !this.followsHasMore) return;
      this.followsLoadingMore = true;
    }
    try {
      const data = await new Promise<Dict>((resolve, reject) => {
        this.api.getFollows(this.uid, this.followsPn, {
          onSuccess: (d: Dict) => resolve(d),
          onError: (code: number, msg: string) => reject({ code, msg })
        });
      });
      const raw = (data?.data || data) as Dict;
      const list = this.parseUserList(raw, 'follow_list');
      if (isRefresh) {
        this.followsList = list;
      } else {
        this.followsList = this.followsList.concat(list);
      }
      this.followsHasMore = getNum(raw, 'has_more') === 1;
      this.followsPn = this.followsPn + 1;
    } catch (e) {
      console.info('TiebaLite: FollowsPage loadFollows fail: ' + String(e));
      if (isRefresh && this.followsList.length === 0) {
        this.followsError = '加载失败，请重试';
      }
    }
    this.followsLoading = false;
    this.followsLoadingMore = false;
  }

  private async loadFans(isRefresh: boolean): Promise<void> {
    if (isRefresh) {
      if (this.fansLoading) return;
      this.fansLoading = true;
      this.fansError = '';
      this.fansPn = 1;
    } else {
      if (this.fansLoadingMore || !this.fansHasMore) return;
      this.fansLoadingMore = true;
    }
    try {
      const data = await new Promise<Dict>((resolve, reject) => {
        this.api.getFans(this.uid, this.fansPn, {
          onSuccess: (d: Dict) => resolve(d),
          onError: (code: number, msg: string) => reject({ code, msg })
        });
      });
      const raw = (data?.data || data) as Dict;
      const list = this.parseUserList(raw, 'user_list');
      if (isRefresh) {
        this.fansList = list;
      } else {
        this.fansList = this.fansList.concat(list);
      }
      const pageObj = raw.page as Dict || {};
      this.fansHasMore = getNum(pageObj, 'has_more') === 1;
      this.fansPn = this.fansPn + 1;
    } catch (e) {
      console.info('TiebaLite: FollowsPage loadFans fail: ' + String(e));
      if (isRefresh && this.fansList.length === 0) {
        this.fansError = '加载失败，请重试';
      }
    }
    this.fansLoading = false;
    this.fansLoadingMore = false;
  }

  private openUserProfile(item: Dict): void {
    const id = getNum(item, 'id');
    if (!id) return;
    NavigationHelper.navigate('pages/user/UserProfilePage', { uid: String(id) });
  }

  @Builder
  userItem(item: Dict) {
    Row() {
      Avatar({
        portrait: buildPortraitUrl(getStr(item, 'portrait')),
        avatarSize: 44,
        defaultName: getStr(item, 'name_show') || getStr(item, 'name') || ''
      })
      Column() {
        Text(getStr(item, 'name_show') || getStr(item, 'name') || '未知用户')
          .fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontWeight(FontWeight.Medium).fontColor(textPrimary(this.isDark))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        if (getStr(item, 'name') && getStr(item, 'name_show') !== getStr(item, 'name')) {
          Text('贴吧ID: ' + getStr(item, 'name'))
            .fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textTertiary(this.isDark)).margin({ top: 2 })
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .margin({ left: 12 }).layoutWeight(1).alignItems(HorizontalAlign.Start)
      Image($r('app.media.ic_arrow_back')).width(Math.round(16 * this.fontScale)).height(Math.round(16 * this.fontScale))
        .fillColor(textTertiary(this.isDark)).rotate({ angle: 180 })
    }
    .width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => { this.openUserProfile(item); })
  }

  build() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor(pageBg(this.isDark))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      Column() {
        Row() {
          Image($r('app.media.ic_arrow_back')).width(Math.round(22 * this.fontScale)).height(Math.round(22 * this.fontScale)).fillColor(textPrimary(this.isDark)).onClick(() => NavigationHelper.back())
          Text(this.currentTab === 0 ? '我的粉丝' : '我的关注').fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold).margin({ left: 16 })
          Blank()
        }
        .padding(12).width('100%').backgroundColor(pageBg(this.isDark))

        Row() {
          Text('粉丝').fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale))
            .fontColor(this.currentTab === 0 ? textAccent(this.primaryColor, this.isDark) : textSecondary(this.isDark))
            .fontWeight(this.currentTab === 0 ? FontWeight.Bold : FontWeight.Normal)
            .layoutWeight(1).textAlign(TextAlign.Center).padding(12)
            .onClick(() => { this.currentTab = 0; })
          Text('关注').fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale))
            .fontColor(this.currentTab === 1 ? textAccent(this.primaryColor, this.isDark) : textSecondary(this.isDark))
            .fontWeight(this.currentTab === 1 ? FontWeight.Bold : FontWeight.Normal)
            .layoutWeight(1).textAlign(TextAlign.Center).padding(12)
            .onClick(() => { this.currentTab = 1; })
        }
        .width('100%').backgroundColor(pageBg(this.isDark))
        .border({ width: { bottom: 1 }, color: dividerColor(this.isDark) })

        if (this.currentTab === 0) {
          if (this.fansLoading && this.fansList.length === 0) {
            LoadingState({ message: '加载中...' })
          } else if (this.fansError && this.fansList.length === 0) {
            ErrorState({ message: this.fansError, onRetryAction: (): void => { void this.loadFans(true); } })
          } else {
            List() {
              ForEach(this.fansList, (item: Dict) => {
                ListItem() {
                  this.userItem(item)
                }
              }, (item: Dict) => String(getNum(item, 'id')))
              if (this.fansHasMore || this.fansList.length > 0) {
                ListItem() {
                  Row() {
                    if (this.fansLoadingMore) {
                      GearLoading({ gearSize: 20, color: this.primaryColor })
                    } else {
                      Text(this.fansHasMore ? '上拉加载更多' : '没有更多了').fontFamily(this.appFontFamily).fontSize(Math.round(13 * this.fontScale)).fontColor(textTertiary(this.isDark))
                    }
                  }
                  .width('100%').height(48).justifyContent(FlexAlign.Center)
                }
              }
            }
            .width('100%').height('100%').edgeEffect(EdgeEffect.Spring)
            .onReachEnd(() => { void this.loadFans(false); })
          }
        } else {
          if (this.followsLoading && this.followsList.length === 0) {
            LoadingState({ message: '加载中...' })
          } else if (this.followsError && this.followsList.length === 0) {
            ErrorState({ message: this.followsError, onRetryAction: (): void => { void this.loadFollows(true); } })
          } else {
            List() {
              ForEach(this.followsList, (item: Dict) => {
                ListItem() {
                  this.userItem(item)
                }
              }, (item: Dict) => String(getNum(item, 'id')))
              if (this.followsHasMore || this.followsList.length > 0) {
                ListItem() {
                  Row() {
                    if (this.followsLoadingMore) {
                      GearLoading({ gearSize: 20, color: this.primaryColor })
                    } else {
                      Text(this.followsHasMore ? '上拉加载更多' : '没有更多了').fontFamily(this.appFontFamily).fontSize(Math.round(13 * this.fontScale)).fontColor(textTertiary(this.isDark))
                    }
                  }
                  .width('100%').height(48).justifyContent(FlexAlign.Center)
                }
              }
            }
            .width('100%').height('100%').edgeEffect(EdgeEffect.Spring)
            .onReachEnd(() => { void this.loadFollows(false); })
          }
        }
      }
      .width('100%').height('100%')
    }
    
  }
}
