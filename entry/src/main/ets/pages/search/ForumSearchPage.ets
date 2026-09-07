import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { KeyboardAvoidMode } from '@ohos.arkui.UIContext';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import SearchRepository from '../../core/repository/SearchRepository';
import PbPageRepository from '../../core/repository/PbPageRepository';
import ThreadCard from '../../components/ThreadCard';
import { Dict } from '../../core/types/Dict';
import { getStr, getNum, buildPortraitUrl, blendWithBg, darkenColor, textAccent, pageBg, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor, withAlpha } from '../../core/utils/DataHelper';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';
import { GripDetector } from '../../core/utils/GripDetector';

@Entry
@Component
struct ForumSearchPage {
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  reduceEffects: boolean = false;
  @StorageLink('fontScale') fontScale: number = 1.0;
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @StorageLink('searchBoxRound') searchBoxRound: number = 100;
  @StorageLink('headerAlpha') headerAlpha: number = 25;
  @StorageLink('headerTint') headerTint: number = 8;
  @StorageLink('cardStyle') cardStyle: number = 0;
  @State bgColor: string = pageBg(AppStorage.Get<boolean>('isDarkTheme') ?? false);
  @State keyword: string = '';
  @State forumName: string = '';
  @State sortMode: number = 2;
  @State selectedScope: number = 0;
  @State threadResults: Dict[] = [];
  @State userList: Dict[] = [];
  @State searchHistory: string[] = [];
  @State showResults: boolean = false;
  @State searching: boolean = false;
  @State refreshKey: number = 0;
  @State suggestions: string[] = [];
  @State showSuggestions: boolean = false;
  @State showScrollTop: boolean = false;
  @State scrollTop: number = 0;
  @State searchBarVisible: boolean = true;
  private lastFabScrollY: number = 0;
  private resultScroller: Scroller = new Scroller();
  private repo: SearchRepository = SearchRepository.getInstance();
  private suggestionTimeoutId: number = -1;

  aboutToAppear(): void {
    try { this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE); } catch (e) {}
    this.bgColor = pageBg(this.isDark);
    const params = router.getParams() as Record<string, string>;
    if (params?.forumName) this.forumName = params.forumName;
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, this.bgColor);
    if (params?.keyword) { this.keyword = params.keyword; this.doSearch(); }
    else this.loadHistory();
  }

  onIsDarkChange(): void {
    this.bgColor = pageBg(this.isDark);
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, this.bgColor);
  }

  onPageShow(): void {
    AppStorage.SetOrCreate('previewActiveId', '');
    AppStorage.SetOrCreate('previewActiveVisible', false);
    const t = AppStorage.get<number>('previewClaimTick') || 0;
    AppStorage.SetOrCreate<number>('previewClaimTick', t + 1);
    this.reduceEffects = AppStorage.get<boolean>('reduceEffects') === true;
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, this.bgColor);
    this.loadHistory();
  }

  async loadHistory(): Promise<void> {
    try {
      this.searchHistory = await this.repo.getSearchHistory();
    } catch (e) {
      console.error('TiebaLite: loadHistory error=' + String(e));
    }
  }

  private onSearchScroll(): void {
    const y = this.resultScroller.currentOffset().yOffset;
    this.scrollTop = y;
    const delta = y - this.lastFabScrollY;
    this.lastFabScrollY = y;
    if (Math.abs(delta) > 2000 || Math.abs(delta) < 0.5) return;
    if (delta > 5) {
      if (this.showScrollTop) { this.showScrollTop = false; }
      if (this.searchBarVisible) { this.searchBarVisible = false; }
    } else if (delta < -5) {
      if (y > 500 && !this.showScrollTop) { this.showScrollTop = true; }
      if (!this.searchBarVisible) { this.searchBarVisible = true; }
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
      } else this.showSuggestions = false;
    } catch (e) { this.showSuggestions = false; }
  }

  build() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor(this.bgColor)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      Column() {
        if (this.searching) {
          Text('搜索中...').fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontColor(textTertiary(this.isDark))
            .width('100%').textAlign(TextAlign.Center).padding(32)
        } else if (!this.showResults) {
          Column() {
            Blank().height(106)
            Text('搜索历史').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark)).width('100%').padding({ left: 16, top: 16, bottom: 8 })
            if (this.searchHistory.length === 0) {
              Text('暂无搜索历史').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark)).padding(24)
            } else {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.searchHistory, (kw: string, idx: number) => {
                  Text(kw).fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textPrimary(this.isDark))
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .backgroundColor(blendWithBg(this.primaryColor, 0.12, this.isDark, '#1E1E1E'))
                    .borderRadius(10)
                    .margin({ right: 8, bottom: 8 })
                    .onClick(() => { this.keyword = kw; this.doSearch(); })
                    .gesture(LongPressGesture({ repeat: false, duration: 400 })
                      .onAction(() => {
                        void this.repo.deleteSearchHistory(kw);
                        this.searchHistory = this.searchHistory.filter((k: string) => k !== kw);
                        promptAction.showToast({ message: '已删除', duration: 1000 });
                      }))
                })
              }
              .width('100%').padding({ left: 16, right: 16 })
            }
          }
          .width('100%')
        } else if (this.threadResults.length === 0) {
          Text('未找到结果').fontFamily(this.appFontFamily).fontSize(Math.round(16 * this.fontScale)).fontColor(textTertiary(this.isDark))
            .width('100%').textAlign(TextAlign.Center).padding(32)
        } else {
          List({ scroller: this.resultScroller }) {
            ListItem() {
              Column() {
                Blank().height(this.searchBarVisible ? 106 : 46)
              }
              .width('100%')
            }
            ForEach(this.threadResults, (item: Dict, idx: number) => {
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
                }).margin({ left: 16, right: 16, top: 6, bottom: 8 })
              }
            })
          }
          .width('100%').layoutWeight(1)
          .edgeEffect(EdgeEffect.Spring)
          .onDidScroll(() => { this.onSearchScroll(); })
          .key('result-' + this.showResults + '-' + this.searching + '-' + this.refreshKey)
        }
      }
      .width('100%').height('100%').justifyContent(FlexAlign.Start)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      Column() {
        Row() {
          Image($r('app.media.ic_arrow_back')).width(22).height(22).fillColor(textPrimary(this.isDark)).onClick(() => router.back())
          TextInput({ text: this.keyword, placeholder: this.forumName ? '搜索 ' + this.forumName : '搜索贴吧...' })
            .layoutWeight(1).height(36).backgroundColor(pageBg(this.isDark)).borderRadius(Math.max(0, Math.round(18 * this.searchBoxRound / 100))).padding({ left: 12 }).margin({ left: 8, right: 8 }).defaultFocus(true)
            .fontColor(textPrimary(this.isDark))
            .placeholderColor(textTertiary(this.isDark))
            .onChange((v: string) => {
              this.keyword = v;
              if (this.suggestionTimeoutId !== -1) clearTimeout(this.suggestionTimeoutId);
              this.suggestionTimeoutId = setTimeout(() => { this.fetchSuggestions(v); }, 300);
            })
            .onSubmit(() => this.doSearch())
          Button('搜索').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor('#FFFFFF')
            .backgroundColor(this.primaryColor).borderRadius(Math.max(0, Math.round(18 * this.searchBoxRound / 100))).height(36).onClick(() => this.doSearch())
        }
        .padding(this.searchBarVisible ? 12 : 0)
        .width('100%')
        .height(this.searchBarVisible ? 60 : 0)
        .clip(true)
        .animation({ duration: 200, curve: Curve.FastOutSlowIn })

        Row() {
          Row() {
            Text('相关')
              .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale))
              .fontColor(this.sortMode === 2 ? textAccent(this.primaryColor, this.isDark) : textTertiary(this.isDark))
              .fontWeight(this.sortMode === 2 ? FontWeight.Bold : FontWeight.Regular)
              .padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .onClick(() => { this.sortMode = 2; if (this.showResults) this.doSearch(); })
            Text('|')
              .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark))
            Text('最新回复')
              .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale))
              .fontColor(this.sortMode === 1 ? textAccent(this.primaryColor, this.isDark) : textTertiary(this.isDark))
              .fontWeight(this.sortMode === 1 ? FontWeight.Bold : FontWeight.Regular)
              .padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .onClick(() => { this.sortMode = 1; if (this.showResults) this.doSearch(); })
          }
          Blank()

          Row() {
            Text('全部')
              .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale))
              .fontColor(this.selectedScope === 0 ? textAccent(this.primaryColor, this.isDark) : textTertiary(this.isDark))
              .fontWeight(this.selectedScope === 0 ? FontWeight.Bold : FontWeight.Regular)
              .padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .onClick(() => { this.selectedScope = 0; if (this.showResults) this.doSearch(); })
            Text('|')
              .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark))
            Text('主题帖')
              .fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale))
              .fontColor(this.selectedScope === 1 ? textAccent(this.primaryColor, this.isDark) : textTertiary(this.isDark))
              .fontWeight(this.selectedScope === 1 ? FontWeight.Bold : FontWeight.Regular)
              .padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .onClick(() => { this.selectedScope = 1; if (this.showResults) this.doSearch(); })
          }
        }
        .width('100%').padding({ left: 12, right: 12, top: 2, bottom: 2 })
      }
      .position({ x: 0, y: 0 })
      .zIndex(2)
      .width('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
      .backgroundColor(this.cardStyle === 1 ? withAlpha(darkenColor(this.bgColor, this.headerTint / 100), 1 - this.headerAlpha / 100) : withAlpha(this.bgColor, 1 - this.headerAlpha / 100))
      .backdropBlur(60)
      .border({ width: { bottom: 1 }, color: blendWithBg(this.primaryColor, 0.15, this.isDark, '#1E1E1E') })

      if (this.showSuggestions) {
        Column().width('100%').height('100%').onClick(() => { this.showSuggestions = false; }).zIndex(3)
      }

      if (this.showSuggestions && this.suggestions.length > 0) {
        Column() {
          ForEach(this.suggestions, (item: string) => {
            Row() {
              Image($r('app.media.ic_search')).width(Math.round(16 * this.fontScale)).height(Math.round(16 * this.fontScale)).fillColor(textTertiary(this.isDark)).margin({ right: 12 })
              Text(item).fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textPrimary(this.isDark))
            }
            .width('100%').padding({ left: 24, top: 10, bottom: 10 })
            .onClick(() => { this.keyword = item; this.showSuggestions = false; this.doSearch(); })
          })
        }
        .width('100%').backgroundColor(this.bgColor)
        .border({ width: { bottom: 1 }, color: blendWithBg(this.primaryColor, 0.15, this.isDark, '#1E1E1E') })
        .position({ top: 60, left: 0, right: 0 }).zIndex(3)
      }

      if (this.showResults && this.scrollTop > 500) {
        Image($r('app.media.ic_arrow_up')).width(Math.round(22 * this.fontScale)).height(Math.round(22 * this.fontScale))
          .fillColor('#FFFFFF')
          .width(44).height(44).borderRadius(22)
          .backgroundColor(this.primaryColor)
          .shadow({ radius: 6, color: shadowColor(this.isDark), offsetY: 3 })
          .position({ bottom: 64, right: 16 })
          .translate({ x: this.showScrollTop ? 0 : 60 })
          .animation({ duration: 250, curve: Curve.FastOutSlowIn })
          .onClick(() => this.resultScroller.scrollEdge(Edge.Top))
      }
    }
    .width('100%').height('100%')
    
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
    if (typeof rawAuthor === 'string') authorName = rawAuthor;
    else if (rawAuthor) {
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
    authorPortrait = authorPortrait.startsWith('http') ? authorPortrait : 'http://tb.himg.baidu.com/sys/portraitn/item/' + authorPortrait;
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

  private async doSearch(): Promise<void> {
    if (!this.keyword.trim()) return;
    this.showSuggestions = false;
    this.searching = true;
    this.showResults = true;
    this.threadResults = [];
    this.userList = [];
    try {
      await this.repo.saveSearchHistory(this.keyword);
    } catch (e) {
      console.error('TiebaLite: saveHistory error=' + String(e));
    }
    try {
      const data = await this.repo.searchThread(this.keyword, 1, this.sortMode, this.forumName, this.selectedScope);
      const d = (data.data as Dict) || data;
      const list = (d.thread_list || d.post_list || d.list || d.data_list || d.data || d.result || d.items || d.feed || []) as Dict[];
      if (list.length > 0) this.threadResults = list;
    } catch (e) {
      console.error('TiebaLite: forumSearch error=' + String(e));
    }
    this.searching = false;
    this.loadHistory();
    this.refreshKey++;
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
      PageTransitionEnter({ duration: 350, curve: Curve.FastOutSlowIn }).slide(SlideEffect.Left)
      PageTransitionExit({ duration: 300, curve: Curve.FastOutSlowIn }).slide(SlideEffect.Right)
    } else {
      PageTransitionEnter({ duration: 350, curve: Curve.FastOutSlowIn }).slide(SlideEffect.Right)
      PageTransitionExit({ duration: 300, curve: Curve.FastOutSlowIn }).slide(SlideEffect.Left)
    }
  }
}

