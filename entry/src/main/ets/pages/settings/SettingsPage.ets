import router from '@ohos.router';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import { blendWithBg, pageBg, cardBg, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../../core/utils/DataHelper';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';

interface SettingItemObject {
  icon: Resource;
  label: string;
  page: string;
}

@Entry
@Component
struct SettingsPage {
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';

  aboutToAppear(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
  }
  onIsDarkChange(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
  }

  onPageShow(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
  }
  private accountItems: SettingItemObject[] = [
    { icon: $r('app.media.ic_person'), label: '账号', page: 'AccountManage' },
    { icon: $r('app.media.ic_key'), label: '签到', page: 'SignInSettings' },
  ];
  private displayItems: SettingItemObject[] = [
    { icon: $r('app.media.ic_settings'), label: '界面', page: 'UISettings' },
    { icon: $r('app.media.ic_font'), label: '字体', page: 'FontSettings' },
    { icon: $r('app.media.ic_target'), label: '习惯', page: 'HabitsSettings' },
  ];
  private privacyItems: SettingItemObject[] = [
    { icon: $r('app.media.ic_lock'), label: '隐私', page: 'PrivacySettings' },
    { icon: $r('app.media.ic_block'), label: '屏蔽', page: 'BlockSettings' },
  ];
  private otherItems: SettingItemObject[] = [
    { icon: $r('app.media.ic_info'), label: '关于', page: 'About' },
  ];

  build() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor(pageBg(this.isDark))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      Column() {
        Row() {
          Image($r('app.media.ic_arrow_back')).width(22).height(22).fillColor(textPrimary(this.isDark)).onClick(() => router.back())
          Text('设置').fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark)).margin({ left: 16 })
          Blank()
        }
        .padding(12).width('100%').backgroundColor(pageBg(this.isDark))

        Scroll() {
          Column() {
            this.section('账号', this.accountItems)
            this.section('显示', this.displayItems)
            this.section('隐私', this.privacyItems)
            this.section('其他', this.otherItems)
          }
          .width('100%').padding({ bottom: 32 }).backgroundColor(pageBg(this.isDark))
        }
          .scrollBar(BarState.Off)
        .width('100%').layoutWeight(1)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      }
      .width('100%').height('100%').justifyContent(FlexAlign.Start)
    }
    .width('100%').height('100%').backgroundColor(pageBg(this.isDark))
  }

  @Builder
  private section(title: string, items: SettingItemObject[]) {
    Column() {
      Text(title).fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).width('100%').padding({ left: 16, top: 16, bottom: 8 })
      Column() {
        ForEach(items, (item: SettingItemObject, idx: number) => {
          Row() {
            Image(item.icon).width(22).height(22).fillColor(textPrimary(this.isDark))
            Text(item.label).fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark)).margin({ left: 12 })
            Blank()
            Image($r('app.media.ic_arrow_back')).width(16).height(16).fillColor(textTertiary(this.isDark)).rotate({ angle: 180 })
          }
          .width('100%').height(48).padding({ left: 16, right: 16 })
          .onClick(() => {
            if (item.page) {
              NavigationHelper.navigate('pages/settings/' + item.page + 'Page');
            }
          })
          if (idx < items.length - 1) {
            Divider().height(1.5).color(dividerColor(this.isDark)).margin({ left: 48 })
          }
        })
      }
      .width('100%')
      .backgroundColor(cardBg(this.isDark))
      .borderRadius(8)
    }
    .width('100%').margin({ top: 8 })
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
