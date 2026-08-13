import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import { AppRouter } from '../components/PbContentRender';
import HomePage from '../pages/main/home/HomePage';
import ExplorePage from '../pages/main/explore/ExplorePage';
import NotificationsPage from '../pages/main/notifications/NotificationsPage';
import UserTabPage from '../pages/main/user/UserTabPage';
import { blendWithBg, cardBg, darkenColor, dividerColor, pageBg, textAccent, textPrimary, textSecondary, textTertiary, withAlpha, buildPortraitUrl, getStr } from '../core/utils/DataHelper';
import PreferencesManager from '../core/storage/PreferencesManager';
import Window from '@ohos.window';
import { NavigationHelper } from '../core/utils/NavigationHelper';
import { consumePendingDeepLink } from '../core/utils/DeepLinkHelper';
import { parseTiebaLink, readClipBoardText, isSameClipText, rememberClipText } from '../core/utils/ClipboardLinkDetector';
import { ClipLink } from '../core/utils/ClipboardLinkDetector';
import PbPageRepository from '../core/repository/PbPageRepository';
import ForumRepository from '../core/repository/ForumRepository';
import SignInService from '../service/SignInService';
import NetworkUtil from '../core/utils/NetworkUtil';
import Avatar from '../components/Avatar';
import { Dict } from '../core/types/Dict';

@Entry
@Component
struct Index {
  private hexR: number = 0;
  private hexG: number = 0;
  private hexB: number = 0;
  @State currentTab: number = 0;
  @State bgColor: string = pageBg(AppStorage.Get<boolean>('isDarkTheme') ?? false);
  @StorageLink('primaryColor') @Watch('onPrimaryColorChanged') primaryColor: string = '#4477E0';
  @StorageLink('secondaryColor') @Watch('onPrimaryColorChanged') secondaryColor: string = '#575E71';
  @StorageLink('tertiaryColor') @Watch('onPrimaryColorChanged') tertiaryColor: string = '#5F5791';
  @State themePrimary: string = '#4477E0';
  @StorageLink('navStyle') navStyle: number = 1;
  @StorageLink('showNavLabels') showNavLabels: boolean = true;
  @StorageLink('isDarkTheme') @Watch('onDarkThemeChanged') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  reduceEffects: boolean = false;
  @State indicatorLeft: number = 0;
  @State indicatorWidth: number = 20;
  @State barWidth: number = 0;

  @State touchX: number = 0;
  @State touchY: number = 0;
  @State liquidR: number = 0;
  @State liquidAlpha: number = 0;
  @State glowX: number = 0;
  @State glowR: number = 0;
  @State glowAlpha: number = 0;
  private liquidCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D();
  private liquidAnimToken: number = 0;
  private glowAnimToken: number = 0;
  @StorageProp('_deepLinkIntent') @Watch('onDeepLinkChanged') deepLinkIntent: string = '';
  @State showClipLinkDialog: boolean = false;
  @State clipLinkType: string = 'thread';
  @State clipLinkTitle: string = '';
  @State clipLinkSubtitle: string = '';
  @State clipLinkTid: number = 0;
  @State clipLinkForumName: string = '';
  @State clipLinkIcon: string = '';

  private tabs: string[] = ['首页', '发现', '通知', '我的'];
  private iconResources: Resource[] = [
    $r('app.media.ic_home'),
    $r('app.media.ic_explore'),
    $r('app.media.ic_notifications'),
    $r('app.media.ic_person')
  ];

  aboutToAppear(): void {
    const t0 = new Date().getTime();
    console.info('TiebaLite: [B1] Index aboutToAppear start t=' + t0);
    AppRouter.navigate = (page: string, params?: Record<string, Object>) => {
      console.info('TiebaLite: [B2] AppRouter.navigate page=' + page + ' url=' + this.getRouteUrl(page));
      const url = this.getRouteUrl(page);
      NavigationHelper.navigate(url, params);
    };
    this.consumeDeepLink();
    this.loadNavPrefs();
    console.info('TiebaLite: [B3] Index aboutToAppear end t=' + (new Date().getTime() - t0) + 'ms');
    setTimeout(() => { this.updateIndicator(); }, 0);
    setTimeout(() => { void this.checkClipboardLink(); }, 800);
    setTimeout(() => { void SignInService.getInstance().tryAutoSignIn(); }, 3000);
  }

  onPrimaryColorChanged(): void {
    this.themePrimary = this.primaryColor;
    this.bgColor = pageBg(this.isDark);
    this.updateSystemBarColors(this.primaryColor);
  }

  onDarkThemeChanged(): void {
    this.bgColor = pageBg(this.isDark);
    this.updateSystemBarColors(this.primaryColor);
  }

  onPageShow(): void {
    AppStorage.SetOrCreate('previewActiveId', '');
    AppStorage.SetOrCreate('previewActiveVisible', false);
    const t = AppStorage.get<number>('previewClaimTick') || 0;
    AppStorage.SetOrCreate<number>('previewClaimTick', t + 1);
    this.reduceEffects = AppStorage.get<boolean>('reduceEffects') === true;
    this.updateSystemBarColors(this.primaryColor);
    this.consumeDeepLink();
    void this.checkClipboardLink();
    void SignInService.getInstance().tryAutoSignIn();
  }

  onDeepLinkChanged(): void {
    this.consumeDeepLink();
  }

  private consumeDeepLink(): void {
    const appStorageVal: string = AppStorage.Get<string>('_deepLinkIntent') || '';
    const pendingVal: string = consumePendingDeepLink();
    const raw: string = appStorageVal || pendingVal || '';
    if (!raw) return;
    AppStorage.SetOrCreate('_deepLinkIntent', '');
    try {
      const intent: Record<string, Object> = JSON.parse(raw) as Record<string, Object>;
      const page: string = intent.page as string || '';
      const noParams: Record<string, Object> = {} as Record<string, Object>;
      const params: Record<string, Object> = (intent.params || noParams) as Record<string, Object>;
      if (page && this.getRouteUrl(page)) {
        console.info('TiebaLite: deepLink navigate page=' + page + ' params=' + JSON.stringify(params));
        setTimeout(() => {
          AppRouter.navigate(page, params);
        }, 500);
      }
    } catch (e) {
      console.warn('TiebaLite: consumeDeepLink err ' + JSON.stringify(e));
    }
  }

  private async checkClipboardLink(): Promise<void> {
    try {
      if (this.showClipLinkDialog) return;
      const prefs = PreferencesManager.getInstance();
      const enabled = await prefs.getBoolean('clipboard_link', true);
      if (!enabled) return;
      const context = getContext(this) as common.UIAbilityContext;
      const text = await readClipBoardText(context);
      if (!text) return;
      const link = parseTiebaLink(text);
      if (!link) return;
      if (isSameClipText(text)) return;
      rememberClipText(text);
      this.clipLinkType = link.type;
      this.clipLinkTid = link.threadId;
      this.clipLinkForumName = link.forumName;
      this.clipLinkTitle = link.type === 'forum' ? link.forumName : link.url;
      this.clipLinkSubtitle = '来自剪贴板的链接';
      this.clipLinkIcon = '';
      this.showClipLinkDialog = true;
      console.info('TiebaLite: clipboard link detected type=' + link.type + ' tid=' + link.threadId + ' forum=' + link.forumName);
      void this.loadClipPreview(link);
    } catch (e) {
      console.warn('TiebaLite: checkClipboardLink err=' + JSON.stringify(e));
    }
  }

  private async loadClipPreview(link: ClipLink): Promise<void> {
    try {
      if (link.type === 'thread' && link.threadId > 0) {
        const d = await PbPageRepository.getInstance().loadThreadPage(link.threadId, 1, false, null);
        const th = ((d as Dict).thread as Dict) || ((d.data as Dict)?.thread as Dict) || {};
        const title = String(th.title || '');
        if (title) {
          this.clipLinkTitle = title;
          const author = th.author as Dict;
          const portrait = String((author ? getStr(author, 'portrait', 'portrait_url') : '') || th.author_portrait || th.authorPortrait || '');
          if (portrait) this.clipLinkIcon = String(portrait);
          const forum = (th.forum as Dict) || ((d as Dict).forum as Dict) || {};
          const fname = String(forum ? getStr(forum, 'name', 'forumName', 'forum_name') : '');
          const replies = Number(th.reply_num || th.replyNum || 0);
          this.clipLinkSubtitle = (fname ? fname : '帖子') + (replies > 0 ? ' · ' + replies + ' 回复' : '');
        }
      } else if (link.type === 'forum' && link.forumName.length > 0) {
        const data = await ForumRepository.getInstance().loadFrsPage(link.forumName, 1, 0, 0);
        const d = (data.data as Dict) || data;
        const forum = (d.forum as Dict) || {};
        const avatar = String(forum ? getStr(forum, 'avatar', 'head', 'forum_avatar', 'icon', 'img', 'picture') : '');
        if (avatar) this.clipLinkIcon = avatar;
        const slogan = String(forum ? getStr(forum, 'slogan') : '');
        if (slogan) this.clipLinkSubtitle = slogan;
      }
    } catch (e) {
      this.clipLinkSubtitle = '预览加载失败';
    }
  }

  private closeClipLinkDialog(): void {
    this.showClipLinkDialog = false;
  }

  private openClipLink(): void {
    this.showClipLinkDialog = false;
    if (this.clipLinkType === 'forum' && this.clipLinkForumName.length > 0) {
      NavigationHelper.navigate('pages/forum/ForumPage', { forumName: this.clipLinkForumName });
    } else if (this.clipLinkTid > 0) {
      NavigationHelper.navigate('pages/thread/ThreadPage', { threadId: String(this.clipLinkTid) });
    }
  }

  private async updateSystemBarColors(_color: string): Promise<void> {
    try {
      const win = await Window.getLastWindow(getContext(this));
      win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: this.isDark ? '#FFFFFF' : '#000000',
        navigationBarContentColor: this.isDark ? '#FFFFFF' : '#000000'
      });
      win.setWindowBackgroundColor(pageBg(this.isDark));
      try { win.setWindowSystemBarEnable(['status']); } catch (_) {}
    } catch (e) {
      console.error('TiebaLite: Index updateSystemBarColors error: ' + JSON.stringify(e));
    }
  }

  async loadNavPrefs(): Promise<void> {
    try {
      const prefs = PreferencesManager.getInstance();
      const ns = await prefs.getInt('nav_style', 0);
      const snl = await prefs.getBoolean('show_nav_labels', true);
      const stp = await prefs.getBoolean('show_thread_preview', true);
      const srf = await prefs.getBoolean('show_recent_forums', true);
      const ssd = await prefs.getBoolean('show_swiper_dots', true);
      const cs = await prefs.getInt('card_style', 0);
      const sb = await prefs.getBoolean('sign_badge', false);
      const pt = await prefs.getInt('page_transition_style', 0);
      const ha = await prefs.getInt('header_alpha', 25);
      const ht = await prefs.getInt('header_tint', 8);
      const sbr = await prefs.getInt('search_box_round', 100);
      AppStorage.SetOrCreate('navStyle', ns);
      AppStorage.SetOrCreate('showNavLabels', snl);
      AppStorage.SetOrCreate('showThreadPreview', stp);
      AppStorage.SetOrCreate('showRecentForums', srf);
      AppStorage.SetOrCreate('showSwiperDots', ssd);
      AppStorage.SetOrCreate('cardStyle', cs);
      AppStorage.SetOrCreate('signBadge', sb);
      AppStorage.SetOrCreate('pageTransitionStyle', pt);
      AppStorage.SetOrCreate('headerAlpha', Math.max(0, Math.min(ha, 100)));
      AppStorage.SetOrCreate('headerTint', Math.max(0, Math.min(ht, 100)));
      AppStorage.SetOrCreate('searchBoxRound', Math.max(0, Math.min(sbr, 100)));
      const ilm = await prefs.getInt('image_load_mode', 0);
      AppStorage.SetOrCreate('imageLoadMode', Math.max(0, Math.min(ilm, 2)));
      NetworkUtil.publishWifiState();
      this.navStyle = ns;
      this.showNavLabels = snl;
      const dt = await prefs.getInt('default_tab', 0);
      const clamped = Math.max(0, Math.min(dt, this.tabs.length - 1));
      if (clamped !== this.currentTab) {
        this.currentTab = clamped;
        setTimeout(() => { this.updateIndicator(); }, 0);
      }
    } catch (e) {}
  }

  switchTab(index: number): void {
    if (this.currentTab === index) return;
    const fromX = this.getTabCenterX(this.currentTab);
    AppStorage.SetOrCreate('previewActiveId', '');
    AppStorage.SetOrCreate('previewActiveVisible', false);
    const t = AppStorage.get<number>('previewClaimTick') || 0;
    AppStorage.SetOrCreate<number>('previewClaimTick', t + 1);
    if (this.reduceEffects) {
      this.currentTab = index;
      this.updateIndicator();
      this.liquidAnimToken++;
      return;
    }
    animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
      this.currentTab = index;
      this.updateIndicator();
    });
    this.liquidAnimToken++;
    this.glowAnimToken++;
    const token = this.glowAnimToken;
    this.runTabGlow(fromX, this.getTabCenterX(index), token);
  }

  handleTabTouch(event: TouchEvent): void {
    const touch = event.touches[0];
    const fx = !this.reduceEffects;
    if (event.type === TouchType.Down) {
      this.liquidAnimToken++;
      this.glowAnimToken++;
      this.touchX = touch.x;
      this.touchY = touch.y;
      if (!fx) return;
      this.liquidAlpha = 0.9;
      this.liquidR = 8;
      this.drawLiquid();
      this.startGlowExpand();
    } else if (event.type === TouchType.Move) {
      const ti = this.getTabFromX(touch.x);
      if (ti !== this.currentTab) {
        this.switchTab(ti);
      }
      if (!fx) return;
      if (Math.abs(touch.x - this.touchX) + Math.abs(touch.y - this.touchY) < 2) return;
      this.touchX = touch.x;
      this.touchY = touch.y;
      this.drawLiquid();
    } else if (event.type === TouchType.Up) {
      const tabIndex = this.getTabFromX(touch.x);
      this.liquidAnimToken++;
      this.liquidR = 0;
      this.liquidAlpha = 0;
      if (fx) {
        this.drawLiquid();
      }
      if (tabIndex !== this.currentTab) {
        this.switchTab(tabIndex);
      }
    } else if (event.type === TouchType.Cancel) {
      this.liquidAnimToken++;
      this.liquidR = 0;
      this.liquidAlpha = 0;
      if (fx) {
        this.drawLiquid();
      }
    }
  }

  private startGlowExpand(): void {
    const token = this.liquidAnimToken;
    const step = (): void => {
      if (token !== this.liquidAnimToken) return;
      if (this.liquidR >= 80) return;
      this.liquidR += 4;
      this.drawLiquid();
      setTimeout(step, 16);
    };
    setTimeout(step, 16);
  }

  private getTabFromX(x: number): number {
    const contentWidth = this.barWidth > 0 ? this.barWidth - 24 : 1;
    const tabWidth = contentWidth / this.tabs.length;
    const index = Math.floor((x - 12) / tabWidth);
    return Math.max(0, Math.min(this.tabs.length - 1, index));
  }

  private getTabCenterX(index: number): number {
    const contentWidth = this.barWidth > 0 ? this.barWidth - 24 : 1;
    const tabWidth = contentWidth / this.tabs.length;
    return 12 + tabWidth * (index + 0.5);
  }

  private drawLiquid(): void {
    const ctx = this.liquidCtx;
    if (!ctx) return;
    const w = this.barWidth;
    const h = 62;
    ctx.clearRect(0, 0, w, h);
    if (this.liquidAlpha < 0.01 || this.liquidR < 1) return;
    ctx.save();
    ctx.globalAlpha = this.liquidAlpha;
    const parsed = this.parseHexColor(this.tertiaryColor);
    const r = parsed[0];
    const g = parsed[1];
    const b = parsed[2];
    const R = this.liquidR;
    ctx.translate(this.touchX, this.touchY);
    ctx.scale(1.2, 0.8);
    ctx.rotate(0.15);
    const gradient = ctx.createRadialGradient(0, 0, 0, 0, 0, R);
    gradient.addColorStop(0, `rgba(${r},${g},${b},0.80)`);
    gradient.addColorStop(0.3, `rgba(${r},${g},${b},0.35)`);
    gradient.addColorStop(0.6, `rgba(${r},${g},${b},0.15)`);
    gradient.addColorStop(1, `rgba(${r},${g},${b},0)`);
    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.arc(0, 0, R, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  private updateIndicator(): void {
    const numTabs = this.tabs.length;
    const contentWidth = this.barWidth > 0 ? this.barWidth - 24 : 1;
    const tabWidth = contentWidth / numTabs;
    this.indicatorWidth = Math.max(20, tabWidth * 0.3);
    this.indicatorLeft = 12 + tabWidth * this.currentTab + (tabWidth - this.indicatorWidth) / 2;
  }

  private parseHexColor(hex: string): number[] {
    const h = hex.replace('#', '');
    return [parseInt(h.substring(0, 2), 16), parseInt(h.substring(2, 4), 16), parseInt(h.substring(4, 6), 16)];
  }

  private mixWithWhite(hex: string, ratio: number): string {
    const rgb = this.parseHexColor(hex);
    const m = (c: number): number => Math.round(c + (255 - c) * ratio);
    return '#' + m(rgb[0]).toString(16).padStart(2, '0') +
      m(rgb[1]).toString(16).padStart(2, '0') +
      m(rgb[2]).toString(16).padStart(2, '0');
  }

  private runTabGlow(fromX: number, toX: number, token: number): void {
    const dir = toX >= fromX ? 1 : -1;
    const dur = 420;
    const t0 = new Date().getTime();
    const step = (): void => {
      if (token !== this.glowAnimToken) return;
      const now = new Date().getTime();
      const p = Math.min(1, (now - t0) / dur);
      const ease = p < 0.5 ? 4 * p * p * p : 1 - Math.pow(-2 * p + 2, 3) / 2;
      this.glowX = fromX + (toX - fromX) * ease;
      this.glowR = 24 + 50 * Math.sin(Math.PI * Math.min(1, p * 1.12));
      this.glowAlpha = Math.sin(Math.PI * p);
      this.drawGlow(dir);
      if (p < 1) {
        setTimeout(step, 16);
      } else {
        this.glowAlpha = 0;
        this.glowR = 0;
        this.drawGlow(dir);
      }
    };
    setTimeout(step, 16);
  }

  private drawGlow(dir: number): void {
    const ctx = this.liquidCtx;
    if (!ctx) return;
    const w = this.barWidth;
    const h = 62;
    ctx.clearRect(0, 0, w, h);
    if (this.glowAlpha < 0.01 || this.glowR < 1) return;
    const rgb = this.parseHexColor(this.mixWithWhite(this.primaryColor, 0.72));
    ctx.save();
    ctx.globalAlpha = Math.min(1, this.glowAlpha);
    ctx.translate(this.glowX, 31);
    ctx.scale(1.6 * dir, 0.85);
    ctx.rotate(0.1);
    const R = this.glowR;
    const g = ctx.createRadialGradient(0, 0, 0, 0, 0, R);
    g.addColorStop(0, `rgba(${rgb[0]},${rgb[1]},${rgb[2]},0.85)`);
    g.addColorStop(0.35, `rgba(${rgb[0]},${rgb[1]},${rgb[2]},0.35)`);
    g.addColorStop(0.7, `rgba(${rgb[0]},${rgb[1]},${rgb[2]},0.12)`);
    g.addColorStop(1, `rgba(${rgb[0]},${rgb[1]},${rgb[2]},0)`);
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(0, 0, R, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  getRouteUrl(page: string): string {
    if (page === 'thread') return 'pages/thread/ThreadPage';
    if (page === 'forum') return 'pages/forum/ForumPage';
    if (page === 'search') return 'pages/search/SearchPage';
    if (page === 'webview') return 'pages/webview/WebViewPage';
    if (page === 'photoview') return 'pages/photoview/PhotoViewPage';
    if (page === 'userprofile') return 'pages/user/UserProfilePage';
    if (page === 'subposts') return 'pages/subposts/SubPostsPage';
    if (page === 'history') return 'pages/history/HistoryPage';
    if (page === 'threadstore') return 'pages/threadstore/ThreadStorePage';
    if (page === 'hottopiclist') return 'pages/hottopic/HotTopicListPage';
    if (page === 'topicdetail') return 'pages/hottopic/TopicDetailPage';
    if (page === 'login') return 'pages/login/LoginPage';
    if (page === 'settings') return 'pages/settings/SettingsPage';
    if (page === 'videoview') return 'pages/videoview/VideoViewPage';
    return 'pages/' + page + '/' + page + 'Page';
  }

  build() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor(this.bgColor)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      Column() {
        Stack() {
          HomePage({ active: this.currentTab === 0 })
            .width('100%').height('100%')
            .visibility(this.currentTab === 0 ? Visibility.Visible : Visibility.Hidden)
          ExplorePage({ active: this.currentTab === 1 })
            .width('100%').height('100%')
            .visibility(this.currentTab === 1 ? Visibility.Visible : Visibility.Hidden)
          NotificationsPage({ active: this.currentTab === 2 })
            .width('100%').height('100%')
            .visibility(this.currentTab === 2 ? Visibility.Visible : Visibility.Hidden)
          UserTabPage({ active: this.currentTab === 3 })
            .width('100%').height('100%')
            .visibility(this.currentTab === 3 ? Visibility.Visible : Visibility.Hidden)
        }
        .width('100%')
        .layoutWeight(1)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .gesture(
          SwipeGesture({ direction: SwipeDirection.Horizontal, speed: 50 })
            .onAction((event?: GestureEvent) => {
              if (event && event.offsetX < 0 && this.currentTab < this.tabs.length - 1) {
                this.switchTab(this.currentTab + 1);
              } else if (event && event.offsetX > 0 && this.currentTab > 0) {
                this.switchTab(this.currentTab - 1);
              }
            })
        )
      }
      .width('100%')
      .height('100%')

      Row() {
        Blank()
        Stack() {
          Canvas(this.liquidCtx)
            .width('100%')
            .height('100%')
            .hitTestBehavior(HitTestMode.None)
          Row() {
            ForEach(this.tabs, (tab: string, index: number) => {
              Column() {
                Image(this.iconResources[index])
                  .width(24).height(24)
                  .fillColor(index === this.currentTab ? textAccent(this.primaryColor, this.isDark) : textSecondary(this.isDark))
                if (this.showNavLabels) {
                  Text(tab)
                    .fontFamily(this.appFontFamily).fontSize(11)
                    .fontColor(index === this.currentTab ? textAccent(this.primaryColor, this.isDark) : textSecondary(this.isDark))
                    .margin({ top: 2 })
                }
                if (index === this.currentTab) {
                  Column()
                    .width(this.indicatorWidth)
                    .height(3)
                    .backgroundColor(this.primaryColor)
                    .borderRadius(2)
                    .margin({ top: 4 })
                }              }
              .layoutWeight(1)
              .padding({ top: 10, bottom: 10 })
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            })
          }
          .width('100%')
          .padding({ left: 12, right: 12 })
          .hitTestBehavior(HitTestMode.None)
        }
        .width('100%')
        .height(62)
        .onTouch((event: TouchEvent) => this.handleTabTouch(event))
        .backgroundColor(withAlpha(cardBg(this.isDark), 0.75))
        .backdropBlur(60)
        .borderRadius(24)
        .clip(true)
        .border({ width: 1, color: blendWithBg(this.tertiaryColor, 0.35, this.isDark, '#1E1E1E') })
        .shadow({ radius: 10, color: blendWithBg(this.primaryColor, 0.30, this.isDark, '#000000'), offsetY: 3 })
        .onAreaChange((_old: Area, newArea: Area) => {
          const w = newArea.width as number;
          if (w > 0 && Math.abs(w - this.barWidth) > 0.5) {
            this.barWidth = w;
            this.updateIndicator();
          }
        })
        Blank()
      }
      .width('100%')
      .padding({ left: 32, right: 32 })
      .position({ bottom: 4 })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])

      if (this.showClipLinkDialog) {
        Column() {
          Column() {
            Text('检测到贴吧链接')
              .fontFamily(this.appFontFamily).fontSize(15).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark))
              .width('100%')
            Row() {
              if (this.clipLinkIcon.length > 0) {
                Avatar({ portrait: buildPortraitUrl(this.clipLinkIcon), avatarSize: 44, defaultName: this.clipLinkTitle })
              } else {
                Image($r('app.media.ic_link')).width(44).height(44).fillColor(textAccent(this.primaryColor, this.isDark))
              }
              Column() {
                Text(this.clipLinkTitle)
                  .fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark))
                  .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.clipLinkSubtitle)
                  .fontFamily(this.appFontFamily).fontSize(12).fontColor(textTertiary(this.isDark))
                  .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 4 })
              }
              .layoutWeight(1).margin({ left: 12 })
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding(12)
            .border({ width: 1, color: dividerColor(this.isDark) })
            .borderRadius(12)
            .margin({ top: 12 })
            Row() {
              Blank()
              Text('忽略')
                .fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark))
                .padding({ left: 16, right: 8, top: 8, bottom: 8 })
                .onClick(() => { this.closeClipLinkDialog(); })
              Text('打开')
                .fontFamily(this.appFontFamily).fontSize(14).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                .padding({ left: 20, right: 20, top: 8, bottom: 8 })
                .backgroundColor(darkenColor(this.primaryColor, 0.15))
                .borderRadius(18)
                .onClick(() => { this.openClipLink(); })
            }
            .width('100%').margin({ top: 14 })
          }
          .width('85%')
          .padding(16)
          .backgroundColor(darkenColor(cardBg(this.isDark), 0.1))
          .borderRadius(16)
          .shadow({ radius: 24, color: '#33000000', offsetY: 8 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#66000000')
        .onClick(() => { this.closeClipLinkDialog(); })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bgColor)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    
  }

  onBackPress(): boolean {
    if (this.showClipLinkDialog) {
      this.closeClipLinkDialog();
      return true;
    }
    if (this.currentTab !== 0) {
      const fromX = this.getTabCenterX(this.currentTab);
      this.currentTab = 0;
      this.updateIndicator();
      if (!this.reduceEffects) {
        this.liquidAnimToken++;
        this.glowAnimToken++;
        const token = this.glowAnimToken;
        this.runTabGlow(fromX, this.getTabCenterX(0), token);
      }
      return true;
    }
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
