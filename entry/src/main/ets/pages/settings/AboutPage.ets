import router from '@ohos.router';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard';
import common from '@ohos.app.ability.common';
import { blendWithBg, pageBg, cardBg, cardRadius, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../../core/utils/DataHelper';
import { Dict } from '../../core/types/Dict';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';

const APP_VERSION = '4.0.0 Beta 4.5.3';
const APP_VERSION_CODE = '390986';
const GITHUB_URL = 'https://github.com/gudianxingkongmeng/TiebaLite-harmony';

@Entry
@Component
struct AboutPage {
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @State buildDate: string = '';

  aboutToAppear(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
    const d = new Date();
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    this.buildDate = y + '-' + m + '-' + day;
  }
  onIsDarkChange(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
  }

  onPageShow(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
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
          Text('关于').fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark)).margin({ left: 16 })
          Blank()
        }
      .padding(12).width('100%').backgroundColor(pageBg(this.isDark))

      Scroll() {
        Column() {
          Column() {
            Circle().width(72).height(72).fill(blendWithBg(this.primaryColor, 0.20, this.isDark))
            Text('TiebaLite').fontFamily(this.appFontFamily).fontSize(22).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark)).margin({ top: 12 })
            Text('一个纯净的第三方贴吧客户端').fontFamily(this.appFontFamily).fontSize(14).fontColor(textSecondary(this.isDark)).margin({ top: 4 })
            Text(APP_VERSION + ' (' + APP_VERSION_CODE + ')').fontFamily(this.appFontFamily).fontSize(13).fontColor(textTertiary(this.isDark)).margin({ top: 12 })
            Text('构建日期: ' + this.buildDate).fontFamily(this.appFontFamily).fontSize(12).fontColor(textTertiary(this.isDark)).margin({ top: 2 })
          }
          .width('100%').padding({ top: 32, bottom: 24 }).alignItems(HorizontalAlign.Center)

          Divider().height(6).color(blendWithBg(this.primaryColor, 0.10, this.isDark)).width('100%')

          Column() {
            this.menuItem($r('app.media.ic_info'), '开源仓库', () => {
              AlertDialog.show({
                title: '开源仓库',
                message: GITHUB_URL,
                primaryButton: {
                  value: '复制',
                  action: () => {
                    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, GITHUB_URL);
                    pasteboard.getSystemPasteboard().setData(data).then(() => {
                      promptAction.showToast({ message: '已复制' });
                    }).catch(() => {
                      promptAction.showToast({ message: '复制失败' });
                    });
                  }
                },
                secondaryButton: {
                  value: '打开',
                  action: () => {
                    const ctx = getContext(this) as common.UIAbilityContext;
                    if (!ctx) return;
                    try {
                      ctx.openLink(GITHUB_URL).catch(() => {
                        this.startAbilityExternal(GITHUB_URL, ctx);
                      });
                    } catch (e) {
                      this.startAbilityExternal(GITHUB_URL, ctx);
                    }
                  }
                },
                cancel: () => {}
              });
            })
            Divider().height(1).color(dividerColor(this.isDark)).margin({ left: 48 })
            this.menuItem($r('app.media.ic_drafts'), '许可证', () => {
              AlertDialog.show({
                title: '许可证',
                message: 'GNU GENERAL PUBLIC LICENSE\nVersion 3',
                confirm: { value: '确定', action: () => {} }
              });
            })
            Divider().height(1).color(dividerColor(this.isDark)).margin({ left: 48 })
            this.menuItem($r('app.media.ic_info'), '免责声明', () => {
              AlertDialog.show({
                title: '免责声明',
                message: '本应用为第三方客户端，使用贴吧公开API。\n不会收集任何用户数据。',
                confirm: { value: '确定', action: () => {} }
              });
            })
          }
          .width('100%').backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(8)).margin({ top: 12 })
        }
        .width('100%').padding({ bottom: 32 }).backgroundColor(pageBg(this.isDark))
      }
        .scrollBar(BarState.Off)
      .layoutWeight(1).width('100%')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
    }
    .width('100%').height('100%').backgroundColor(pageBg(this.isDark))
  }

  private startAbilityExternal(url: string, ctx: common.UIAbilityContext): void {
    if (!ctx) return;
    try {
      ctx.startAbility({
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: url
      }).catch((e: Error) => {
        console.error('TiebaLite: openExternal failed err=' + JSON.stringify(e));
      });
    } catch (e) {}
  }

  @Builder
  private menuItem(iconRes: Resource, label: string, onClick: () => void) {
    Row() {
      Image(iconRes).width(18).height(18).fillColor(textPrimary(this.isDark))
      Text(label).fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark)).margin({ left: 12 })
      Blank()
      Image($r('app.media.ic_arrow_back')).width(16).height(16).fillColor(textTertiary(this.isDark)).rotate({ angle: 180 })
    }
    .width('100%').height(48).padding({ left: 16, right: 16 })
    .onClick(() => onClick())
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
