import router from '@ohos.router';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import PreferencesManager from '../../core/storage/PreferencesManager';
import DatabaseManager from '../../core/storage/DatabaseManager';
import SearchRepository from '../../core/repository/SearchRepository';
import promptAction from '@ohos.promptAction';
import { blendWithWhite, darkenColor, blendWithBg, pageBg, cardBg, cardRadius, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../../core/utils/DataHelper';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';

@Entry
@Component
struct PrivacySettingsPage {
  @State readClipBoardLink: boolean = true;
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  @StorageLink('appFontFamily') appFontFamily: string = '';

  private prefs: PreferencesManager = PreferencesManager.getInstance();

  async aboutToAppear(): Promise<void> {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
    this.readClipBoardLink = await this.prefs.getBoolean('clipboard_link', true);
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
          Image($r('app.media.ic_arrow_back')).width(22).height(22).fillColor(textPrimary(this.isDark))
          Text('隐私设置').fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark)).margin({ left: 16 })
          Blank()
        }
      .padding(12).width('100%').backgroundColor(pageBg(this.isDark))

      Scroll() {
        Column() {
          Text('隐私').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).width('100%').padding(16)

          Column() {
            Row() {
              Text('读取剪贴板链接').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.readClipBoardLink })
                .onChange(async (v) => {
                  this.readClipBoardLink = v;
                  await this.prefs.putBoolean('clipboard_link', v);
                })
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })
          }
        .width('100%').backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(8))

          Text('缓存').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).width('100%').padding(16)

          Column() {
            Row() {
              Text('清除搜索历史').fontFamily(this.appFontFamily).fontSize(16).fontColor('#FF4444')
              Blank()
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })
            .onClick(() => {
              AlertDialog.show({
                title: '清除搜索历史',
                message: '确定要清除搜索历史吗？',
                primaryButton: {
                  value: '取消',
                  action: () => {}
                },
                secondaryButton: {
                  value: '清除',
                  action: async () => {
                    try {
                      await SearchRepository.getInstance().clearSearchHistory();
                      promptAction.showToast({ message: '已清除搜索历史', duration: 1000 });
                    } catch (e) {
                      promptAction.showToast({ message: '清除失败', duration: 1000 });
                    }
                  }
                },
                cancel: () => {}
              });
            })

            Divider().height(1).color(dividerColor(this.isDark)).margin({ left: 16 })

            Row() {
              Text('清除浏览历史').fontFamily(this.appFontFamily).fontSize(16).fontColor('#FF4444')
              Blank()
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })
            .onClick(() => {
              AlertDialog.show({
                title: '清除浏览历史',
                message: '确定要清除浏览历史吗？',
                primaryButton: {
                  value: '取消',
                  action: () => {}
                },
                secondaryButton: {
                  value: '清除',
                  action: async () => {
                    await DatabaseManager.getInstance().executeSql('DELETE FROM thread_history');
                    await DatabaseManager.getInstance().executeSql('DELETE FROM forum_history');
                  }
                },
                cancel: () => {}
              });
            })
          }
          .width('100%').backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(8))
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
