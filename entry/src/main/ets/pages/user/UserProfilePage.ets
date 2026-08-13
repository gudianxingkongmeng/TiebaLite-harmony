import router from '@ohos.router';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import Window from '@ohos.window';
import UserProfileRepository from '../../core/repository/UserProfileRepository';
import BlockRepository from '../../core/repository/BlockRepository';
import promptAction from '@ohos.promptAction';
import Avatar from '../../components/Avatar';
import LoadingState from '../../components/LoadingState';
import ErrorState from '../../components/ErrorState';
import AccountManager from '../../core/auth/AccountManager';
import { Dict } from '../../core/types/Dict';
import { getStr, getNum, buildPortraitUrl, blendWithBg, textAccent, pageBg, cardBg, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../../core/utils/DataHelper';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';

@Entry
@Component
struct UserProfilePage {
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  reduceEffects: boolean = false;
  @StorageLink('fontScale') fontScale: number = 1.0;
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @State uid: number = 0;
  @State profile: Dict | null = null;
  @State userPosts: Dict[] = [];
  @State userReplies: Dict[] = [];
  @State selectedTab: number = 0;
  @State loading: boolean = true;
  @State loadingTab: boolean = false;
  @State error: string = '';
  @State isFollowing: boolean = false;
  @State isBlocked: boolean = false;
  @State postCount: string = '0';
  @State replyCount: string = '0';
  @State agreeCount: string = '0';
  @State fanCount: string = '0';
  @State followCount: string = '0';
  @State isSelf: boolean = false;
  @State genderText: string = '';
  @State ipText: string = '';
  private repo: UserProfileRepository = UserProfileRepository.getInstance();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.uid = parseInt(params?.uid || '0');
    const account = AccountManager.getInstance().getCurrentAccountSync();
    this.isSelf = account !== null && account.uid === this.uid;
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
    this.loadProfile();
    BlockRepository.getInstance().ensureLoaded().then(() => {
      this.isBlocked = BlockRepository.getInstance().isUserBlocked(this.uid);
    }).catch(() => {});
  }

  onIsDarkChange(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
  }

  onPageShow(): void {
    this.reduceEffects = AppStorage.get<boolean>('reduceEffects') === true;
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
  }

  async loadProfile(): Promise<void> {
    this.loading = true;
    let fallbackUsed = false;
    let data: Dict;
    try {
      const prof = await this.repo.loadProfileProtobufDirect(this.uid);
      if (prof.threadNum > 0 || prof.postNum > 0 || prof.fanNum > 0 || prof.followNum > 0 || prof.agreeNum > 0) {
        this.postCount = String(prof.threadNum);
        this.replyCount = String(prof.postNum);
        this.fanCount = String(prof.fanNum);
        this.followCount = String(prof.followNum);
        this.agreeCount = String(prof.agreeNum);
        this.isFollowing = prof.isFollowing;
        this.profile = { uid: prof.uid, portrait: prof.portrait, name: prof.userName, nickname: prof.nickName, intro: prof.sign, gender: prof.gender };
        AppStorage.Set('myPostCount', this.postCount);
        AppStorage.Set('myFanCount', this.fanCount);
        AppStorage.Set('myFollowCount', this.followCount);
        this.loadUserPosts();
        this.loading = false;
        return;
      }
      console.info('TiebaLite: profileProtobufDirect all zeros, fallback to json api');
    } catch (_e) {
      console.info('TiebaLite: profileProtobufDirect failed, fallback to json api');
    }
    try {
      data = await this.repo.loadProfile(this.uid);
    } catch (_e) {
      try {
        data = await this.repo.loadStatsViaMiniApi(this.uid);
        fallbackUsed = true;
      } catch (_e2) {
        try {
          data = await this.repo.loadStatsViaUserInfo(this.uid);
          fallbackUsed = true;
        } catch (_e3) {
          this.error = '加载用户资料失败';
          this.loading = false;
          return;
        }
      }
    }
    try {
      const raw = (data?.data || data) as Dict;
      let rawUser = raw.user as Dict || {};
      const rawAgree = raw.user_agree_info as Dict || {};
      console.info('TiebaLite: profile rawKeys=' + Object.keys(raw).join(',') + ' userKeys=' + Object.keys(rawUser).join(',') + ' agreeKeys=' + Object.keys(rawAgree).join(',') + ' fallback=' + fallbackUsed);
      // 瀹夊崜proto: User对象卼hread_num(87)/post_num(37)/fans_num(30)/concern_num(31); DataRes.user_agree_info.total_agree_num(118)
      this.postCount = getStr(rawUser, 'thread', 'threadNum', 'thread_num', 'thread_count');
      if (!this.postCount || this.postCount === '0') this.postCount = getStr(raw, 'thread', 'threadNum', 'thread_num', 'thread_count');
      this.replyCount = getStr(rawUser, 'post', 'postNum', 'post_num', 'post_count', 'replyNum', 'reply_num', 'reply_count');
      if (!this.replyCount || this.replyCount === '0') this.replyCount = getStr(raw, 'post', 'postNum', 'post_num', 'post_count', 'replyNum', 'reply_num', 'reply_count');
      this.agreeCount = getStr(rawAgree, 'total_agree_num', 'totalAgreeNum', 'agree', 'agreeNum', 'agree_num');
      if (!this.agreeCount || this.agreeCount === '0') this.agreeCount = getStr(rawUser, 'agree', 'totalAgreeNum', 'total_agree_num', 'agreeNum', 'agree_num');
      if (!this.agreeCount || this.agreeCount === '0') this.agreeCount = getStr(raw, 'agree', 'totalAgreeNum', 'total_agree_num', 'agreeNum', 'agree_num');
      this.fanCount = getStr(rawUser, 'fans', 'fansNum', 'fans_num', 'follower_count', 'followers');
      if (!this.fanCount || this.fanCount === '0') this.fanCount = getStr(raw, 'fans', 'fansNum', 'fans_num', 'follower_count', 'followers');
      this.followCount = getStr(rawUser, 'follow', 'followNum', 'follow_num', 'following_count', 'concernNum', 'concern_num', 'following');
      if (!this.followCount || this.followCount === '0') this.followCount = getStr(raw, 'follow', 'followNum', 'follow_num', 'following_count', 'concernNum', 'concern_num', 'following');
      AppStorage.Set('myPostCount', this.postCount);
      AppStorage.Set('myFanCount', this.fanCount);
      AppStorage.Set('myFollowCount', this.followCount);
      this.profile = raw;
      if (!raw.portrait && !raw.name && !raw.nickname) {
        console.info('TiebaLite: profile data keys=' + Object.keys(raw).join(','));
        const user = raw.user as Dict || {};
        if (user) this.profile = user;
        const userInfo = raw.user_info as Dict || {};
        if (userInfo && !this.profile) this.profile = userInfo;
      }

      rawUser = raw.user as Dict || {};
      const genderVal = getNum(raw, 'gender', 'sex') || getNum(rawUser, 'gender', 'sex') || 0;
      if (genderVal === 1) this.genderText = '男';
      else if (genderVal === 2) this.genderText = '女';
      else this.genderText = '';

      this.ipText = getStr(raw, 'ip', 'ip_address', 'ipAddr', 'ipLocation', 'location', 'ip_location')
        || getStr(rawUser, 'ip', 'ip_address', 'ip_location')
        || '';

      this.loadUserPosts();
    } catch (e) {
      this.error = (e as Dict)?.msg as string || String(e);
    }
    this.loading = false;
  }

  build() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor(pageBg(this.isDark))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      Column() {
        Row() {
          Image($r('app.media.ic_arrow_back')).width(Math.round(22 * this.fontScale)).height(Math.round(22 * this.fontScale)).fillColor(textPrimary(this.isDark)).onClick(() => router.back())
          Text('用户资料').fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold).margin({ left: 16 })
          Blank()
        }
        .padding(12).width('100%').backgroundColor(pageBg(this.isDark))

      if (this.loading) {
        LoadingState({ message: '加载中...' })
      } else if (this.error) {
        ErrorState({ message: this.error, onRetryAction: (): void => { void this.loadProfile(); } })
      } else if (this.profile) {
        Scroll() {
          Column() {
            Column() {
              Avatar({ portrait: buildPortraitUrl(getStr(this.profile!, 'portrait', 'avatar', 'user_portrait', 'portrait_url')), avatarSize: 64, defaultName: getStr(this.profile!, 'name', 'nickname', 'userName', 'user_name', 'un', 'username') })
              Text(getStr(this.profile!, 'nickname', 'name', 'userName', 'user_name', 'un', 'username', 'name_show')).fontFamily(this.appFontFamily).fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 8 })
              Text('@' + getStr(this.profile!, 'name', 'userName', 'user_name', 'un', 'username') + '  (ID: ' + this.uid + ')').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark)).margin({ top: 2 })
              if (getStr(this.profile!, 'intro', 'introduction', 'desc', 'abstract', 'slogan')) {
                Text(getStr(this.profile!, 'intro', 'introduction', 'desc', 'abstract', 'slogan')).fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textSecondary(this.isDark)).margin({ top: 8 }).maxLines(2)
              }

              if (this.genderText || this.ipText) {
                Row() {
                  if (this.genderText) {
                    Text('性别: ' + this.genderText).fontFamily(this.appFontFamily).fontSize(Math.round(13 * this.fontScale)).fontColor(textTertiary(this.isDark))
                  }
                  if (this.genderText && this.ipText) {
                    Text(' | ').fontFamily(this.appFontFamily).fontSize(Math.round(13 * this.fontScale)).fontColor(textTertiary(this.isDark)).margin({ left: 4, right: 4 })
                  }
                  if (this.ipText) {
                    Text('IP: ' + this.ipText).fontFamily(this.appFontFamily).fontSize(Math.round(13 * this.fontScale)).fontColor(textTertiary(this.isDark))
                  }
                }.margin({ top: 6 }).width('100%').justifyContent(FlexAlign.Center)
              }

              Row() {
                this.statItem('帖子', this.postCount)
                this.statItem('回复', this.replyCount)
                this.statItem('获赞', this.agreeCount)
                this.statItem('粉丝', this.fanCount)
                this.statItem('关注', this.followCount)
              }
              .width('100%').padding(16)

              if (!this.isSelf) {
                Button(this.isFollowing ? '已关注' : '+ 关注')
                  .width(200).height(36)
                  .fontColor(this.isFollowing ? textSecondary(this.isDark) : '#FFFFFF')
                  .backgroundColor(this.isFollowing ? cardBg(this.isDark) : '#4477E0')
                  .borderRadius(18)
                  .onClick(() => this.toggleFollow())
                Button(this.isBlocked ? '取消屏蔽' : '屏蔽该用户')
                  .width(120).height(36)
                  .fontColor(this.isBlocked ? '#FF4444' : textSecondary(this.isDark))
                  .backgroundColor(this.isBlocked ? cardBg(this.isDark) : cardBg(this.isDark))
                  .borderRadius(18)
                  .margin({ left: 12 })
                  .onClick(() => this.toggleBlock())
              }
            }
            .width('100%').padding(16).backgroundColor(cardBg(this.isDark))

            Row() {
              Text('主题帖').fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(this.selectedTab === 0 ? textAccent(this.primaryColor, this.isDark) : textSecondary(this.isDark))
                .layoutWeight(1).textAlign(TextAlign.Center).padding(12)
                .onClick(() => { this.selectedTab = 0; this.loadUserPosts(); })
              Text('回复').fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(this.selectedTab === 1 ? textAccent(this.primaryColor, this.isDark) : textSecondary(this.isDark))
                .layoutWeight(1).textAlign(TextAlign.Center).padding(12)
                .onClick(() => { this.selectedTab = 1; this.loadUserPosts(); })
            }
            .width('100%').backgroundColor(cardBg(this.isDark))
            .border({ width: { bottom: 1 }, color: dividerColor(this.isDark) })

            if (this.loadingTab) {
              Text('加载中...').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark)).padding(32).width('100%').textAlign(TextAlign.Center)
            } else if (this.selectedTab === 0 && this.userPosts.length === 0) {
              Text('暂无帖子').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark)).padding(32).width('100%').textAlign(TextAlign.Center)
            } else if (this.selectedTab === 1 && this.userReplies.length === 0) {
              Text('暂无回复').fontFamily(this.appFontFamily).fontSize(Math.round(14 * this.fontScale)).fontColor(textTertiary(this.isDark)).padding(32).width('100%').textAlign(TextAlign.Center)
            } else if (this.selectedTab === 0) {
              ForEach(this.userPosts, (post: Dict, idx: number) => {
                Column() {
                  Text(this.getPostTitle(post)).fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(textPrimary(this.isDark)).maxLines(3).lineHeight(21).width('100%')
                  Row() {
                    Text(this.formatUserTime(getStr(post, 'createTime', 'create_time', 'time', 'post_time', 'timestamp'))).fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textTertiary(this.isDark))
                    Blank()
                    if (getStr(post, 'fname', 'forum_name', 'forumName')) {
                      Text(getStr(post, 'fname', 'forum_name', 'forumName')).fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textAccent(this.primaryColor, this.isDark)).margin({ left: 8 })
                    }
                    Row() {
                      Image($r('app.media.ic_favorite')).width(Math.round(12 * this.fontScale)).height(Math.round(12 * this.fontScale)).fillColor(textTertiary(this.isDark))
                      Text(' ' + this.getAgreeCount(post)).fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textTertiary(this.isDark))
                    }.margin({ left: 8 })
                  }.width('100%').margin({ top: 6 })
                }
                .width('100%').padding(12)
                .backgroundColor(cardBg(this.isDark))
                .margin({ bottom: 1 })
                .onClick(() => {
                  NavigationHelper.navigate('pages/thread/ThreadPage', {
                    threadId: getStr(post, 'id', 'tid', 'thread_id', 'threadId'),
                    forumName: getStr(post, 'fname', 'forum_name', 'forumName')
                  });
                })
              })
            } else {
              ForEach(this.userReplies, (post: Dict, idx: number) => {
                Column() {
                  Text(this.getPostTitle(post)).fontFamily(this.appFontFamily).fontSize(Math.round(15 * this.fontScale)).fontColor(textPrimary(this.isDark)).maxLines(3).lineHeight(21).width('100%')
                  Row() {
                    Text(this.formatUserTime(getStr(post, 'createTime', 'create_time', 'time', 'post_time', 'timestamp'))).fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textTertiary(this.isDark))
                    Blank()
                    if (getStr(post, 'fname', 'forum_name', 'forumName')) {
                      Text(getStr(post, 'fname', 'forum_name', 'forumName')).fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textAccent(this.primaryColor, this.isDark)).margin({ left: 8 })
                    }
                    Row() {
                      Image($r('app.media.ic_favorite')).width(Math.round(12 * this.fontScale)).height(Math.round(12 * this.fontScale)).fillColor(textTertiary(this.isDark))
                      Text(' ' + this.getAgreeCount(post)).fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textTertiary(this.isDark))
                    }.margin({ left: 8 })
                  }.width('100%').margin({ top: 6 })
                }
                .width('100%').padding(12)
                .backgroundColor(cardBg(this.isDark))
                .margin({ bottom: 1 })
                .onClick(() => {
                  NavigationHelper.navigate('pages/thread/ThreadPage', {
                    threadId: getStr(post, 'id', 'tid', 'thread_id', 'threadId'),
                    forumName: getStr(post, 'fname', 'forum_name', 'forumName')
                  });
                })
              })
            }
          }
          .width('100%').padding({ bottom: 8 })
        }
          .scrollBar(BarState.Off)
        .width('100%').layoutWeight(1)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
        .backgroundColor(pageBg(this.isDark))
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start).backgroundColor(pageBg(this.isDark)).expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
  .width('100%').height('100%')
  
  }

  @Builder
  private statItem(label: string, value: string) {
    Column() {
      Text(value && value !== '0' ? value : '0').fontFamily(this.appFontFamily).fontSize(18).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark))
      Text(label).fontFamily(this.appFontFamily).fontSize(Math.round(12 * this.fontScale)).fontColor(textTertiary(this.isDark)).margin({ top: 2 })
    }
    .layoutWeight(1)
  }

  private extractAnyArray(d: Dict, data: Dict): Dict[] {
    const keys = ['post_list', 'postList', 'thread_list', 'threadList', 'reply_list', 'replyList', 'list', 'data_list', 'dataList', 'items', 'feeds', 'posts', 'threads', 'postInfoList', 'post_info_list', 'threadInfoList', 'thread_info_list'];
    // Try d (data.data) first
    for (const k of keys) { const v = d[k] as Dict[] | undefined; if (v && Array.isArray(v) && v.length > 0) return v; }
    // Try d.data (double nested)
    const dd = d.data as Dict | undefined;
    if (dd) { for (const k of keys) { const v = dd[k] as Dict[] | undefined; if (v && Array.isArray(v) && v.length > 0) return v; } }
    // Try data top-level
    for (const k of keys) { const v = data[k] as Dict[] | undefined; if (v && Array.isArray(v) && v.length > 0) return v; }
    // Try data.data.data (triple nested)
    const ddd = dd?.data as Dict | undefined;
    if (ddd) { for (const k of keys) { const v = ddd[k] as Dict[] | undefined; if (v && Array.isArray(v) && v.length > 0) return v; } }
    // If d itself is an array
    if (Array.isArray(d) && d.length > 0) return d as Dict[];
    if (Array.isArray(data) && (data as Object[]).length > 0) return data as Dict[];
    // Last resort: find ANY array with objects that have title/thread_id
    for (const src of [d, data, dd || {}]) {
      for (const k of Object.keys(src)) {
        const v = src[k];
        if (Array.isArray(v) && v.length > 0 && typeof v[0] === 'object' && (v[0] as Dict).thread_id !== undefined) {
          return v as Dict[];
        }
      }
    }
    return [];
  }

  private async loadUserPosts(): Promise<void> {
    this.loadingTab = true;
    try {
      const data: Dict = await this.repo.loadUserPosts(this.uid, 1, this.selectedTab === 0);
      const d = (data.data as Dict) || data;
      console.info('TiebaLite: UserProfilePage dataKeys=' + Object.keys(d).join(',') + ' topKeys=' + Object.keys(data).join(','));

      const arr = this.extractAnyArray(d, data);
      if (this.selectedTab === 0) {
        this.userPosts = arr;
        console.info('TiebaLite: userPosts loaded count=' + this.userPosts.length);
      } else {
        this.userReplies = arr;
        console.info('TiebaLite: userReplies loaded count=' + this.userReplies.length);
      }
    } catch (e) {
      console.error('TiebaLite: loadUserPosts error=' + String(e));
    }
    this.loadingTab = false;
  }

  private async toggleFollow(): Promise<void> {
    try {
      if (this.isFollowing) {
        await this.repo.unfollowUser(String(this.profile?.portrait || ''));
        this.isFollowing = false;
      } else {
        await this.repo.followUser(String(this.profile?.portrait || ''));
        this.isFollowing = true;
      }
    } catch (e) {}
  }

  private async toggleBlock(): Promise<void> {
    const blockRepo = BlockRepository.getInstance();
    const name = getStr(this.profile!, 'nickname', 'name', 'userName', 'user_name', 'un', 'username') || '';
    try {
      if (this.isBlocked) {
        await blockRepo.removeBlockUser(this.uid);
        this.isBlocked = false;
        promptAction.showToast({ message: '已取消屏蔽', duration: 1000 });
      } else {
        await blockRepo.addBlockUser(this.uid, name);
        this.isBlocked = true;
        promptAction.showToast({ message: '已屏蔽该用户', duration: 1000 });
      }
    } catch (e) {
      promptAction.showToast({ message: '操作失败', duration: 1000 });
    }
  }

  private getPostTitle(post: Dict): string {
    const t = getStr(post, 'title', 'abstract', 'firstPostContent', 'first_post_content');
    if (t) return t;
    if (Array.isArray(post.content)) return this.getFirstText(post.content as Dict[]);
    const media = post.media as Dict[] || [];
    if (media.length > 0) return '[Image]';
    return getStr(post, 'content', 'text', 'excerpt') || '(No content)';
  }

  private getAgreeCount(post: Dict): string {
    const agree = post.agree as Dict || {};
    const c = getNum(agree, 'agreeNum', 'agree_num', 'count', 'num') || getNum(post, 'agreeNum', 'agree_num', 'likeNum', 'like_num');
    if (c <= 0) return '0';
    if (c >= 10000) return (c / 10000).toFixed(1) + 'w';
    return String(c);
  }

  private getFirstText(contents: Dict[]): string {
    if (!contents || contents.length === 0) return '';
    for (const c of contents) {
      if (c.text && c.type !== 2) return String(c.text);
    }
    return '';
  }

  private formatUserTime(timeStr: string): string {
    if (!timeStr) return '';
    const ts = Number(timeStr);
    if (isNaN(ts)) return timeStr;
    const d = new Date(ts > 1e12 ? ts : ts * 1000);
    const now = new Date();
    const diff = now.getTime() - d.getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 1) return '刚刚';
    if (mins < 60) return mins + '分钟前';
    const pad = (n: number): string => n < 10 ? '0' + n : String(n);
    if (d.getDate() === now.getDate() && d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear()) {
      return pad(d.getHours()) + ':' + pad(d.getMinutes());
    }
    const yesterday = new Date(now);
    yesterday.setDate(yesterday.getDate() - 1);
    if (d.getDate() === yesterday.getDate() && d.getMonth() === yesterday.getMonth() && d.getFullYear() === yesterday.getFullYear()) {
      return '昨天 ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
    }
    if (d.getFullYear() === now.getFullYear()) {
      return pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
    }
    return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
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
