import router from '@ohos.router';
import { KeyboardAvoidMode } from '@ohos.arkui.UIContext';
import { blendWithBg, pageBg, cardBg, cardRadius, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../../core/utils/DataHelper';
import DatabaseManager from '../../core/storage/DatabaseManager';
import BlockRepository from '../../core/repository/BlockRepository';
import { textAccent } from '../../core/utils/DataHelper';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';
import { NavigationHelper } from '../../core/utils/NavigationHelper';

interface BlockedUser {
  uid: number;
  name: string;
}

@Entry
@Component
struct BlockSettingsPage {
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @State keywords: string[] = [];
  @State blockedUsers: BlockedUser[] = [];
  @State blockedForums: string[] = [];
  @State showAddInput: boolean = false;
  @State addKeywordText: string = '';

  private db: DatabaseManager = DatabaseManager.getInstance();
  private blockRepo: BlockRepository = BlockRepository.getInstance();

  async aboutToAppear(): Promise<void> {
    try { this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE); } catch (e) {}
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
    await this.loadBlockData();
  }
  onIsDarkChange(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
  }

  onPageShow(): void {
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

  private async loadBlockData(): Promise<void> {
    await this.blockRepo.loadBlockRules();

    const kwRs = await this.db.query('SELECT keyword FROM block_keyword WHERE whitelisted=0');
    this.keywords = [];
    while (kwRs.goToNextRow()) {
      this.keywords.push(kwRs.getString(kwRs.getColumnIndex('keyword')));
    }
    kwRs.close();

    const userRs = await this.db.query('SELECT uid, name FROM block_user WHERE whitelisted=0');
    this.blockedUsers = [];
    while (userRs.goToNextRow()) {
      this.blockedUsers.push({
        uid: userRs.getLong(userRs.getColumnIndex('uid')),
        name: userRs.getString(userRs.getColumnIndex('name'))
      });
    }
    userRs.close();

    const forumRs = await this.db.query('SELECT name FROM block_forum');
    this.blockedForums = [];
    while (forumRs.goToNextRow()) {
      this.blockedForums.push(forumRs.getString(forumRs.getColumnIndex('name')));
    }
    forumRs.close();
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
          Text('屏蔽管理').fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark)).margin({ left: 16 })
          Blank()
        }
      .padding(12).width('100%').backgroundColor(pageBg(this.isDark))

      Scroll() {
        Column() {
          Text('屏蔽关键词').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).width('100%').padding(16)

          Column() {
            Row() {
              Text('+ 添加关键词').fontFamily(this.appFontFamily).fontSize(16).fontColor(textAccent(this.primaryColor, this.isDark))
              Blank()
            }
            .width('100%').height(48).padding({ left: 16, right: 16 })
            .onClick(() => {
              this.showAddInput = !this.showAddInput;
              this.addKeywordText = '';
            })

            if (this.showAddInput) {
              Divider().height(1.5).color(dividerColor(this.isDark)).margin({ left: 16 })

              Row() {
                TextInput({ placeholder: '输入关键词', text: this.addKeywordText })
                  .layoutWeight(1).height(36).fontFamily(this.appFontFamily).fontSize(14)
                  .onChange((v: string) => { this.addKeywordText = v; })
                Text('添加').fontFamily(this.appFontFamily).fontSize(14).fontColor(textAccent(this.primaryColor, this.isDark)).margin({ left: 8 })
                  .onClick(async () => {
                    if (this.addKeywordText.trim()) {
                      await this.blockRepo.addBlockKeyword(this.addKeywordText.trim());
                      this.showAddInput = false;
                      this.addKeywordText = '';
                      await this.loadBlockData();
                    }
                  })
              }
              .width('100%').height(48).padding({ left: 16, right: 16 })
            }

            if (this.keywords.length === 0) {
              Divider().height(1.5).color(dividerColor(this.isDark)).margin({ left: 16 })
              Text('暂无屏蔽关键词').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark))
                .width('100%').padding(16).textAlign(TextAlign.Center)
            }

            ForEach(this.keywords, (kw: string, idx: number) => {
              Divider().height(1.5).color(dividerColor(this.isDark)).margin({ left: 16 })
              Row() {
                Text(kw).fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark)).layoutWeight(1)
                Text('删除').fontFamily(this.appFontFamily).fontSize(14).fontColor('#FF4444')
                  .onClick(async () => {
                    AlertDialog.show({
                      title: '删除关键词',
                      message: '确定要删除: ' + kw + '？',
                      primaryButton: {
                        value: '取消',
                        action: () => {}
                      },
                      secondaryButton: {
                        value: '删除',
                        action: async () => {
                          await this.blockRepo.removeBlockKeyword(kw);
                          await this.loadBlockData();
                        }
                      },
                      cancel: () => {}
                    });
                  })
              }
              .width('100%').height(48).padding({ left: 16, right: 16 })
            })
          }
          .width('100%').backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(8))

          Text('屏蔽用户').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).width('100%').padding(16)

          Column() {
            if (this.blockedUsers.length === 0) {
              Text('暂无屏蔽用户').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark))
                .width('100%').padding(16).textAlign(TextAlign.Center)
            }

            ForEach(this.blockedUsers, (u: BlockedUser, idx: number) => {
              if (idx > 0) {
                Divider().height(1.5).color(dividerColor(this.isDark)).margin({ left: 16 })
              }
              Row() {
                Column() {
                  Text(u.name || 'User ' + u.uid).fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
                  Text('UID: ' + u.uid).fontFamily(this.appFontFamily).fontSize(12).fontColor(textTertiary(this.isDark)).margin({ top: 2 })
                }
                .layoutWeight(1).alignItems(HorizontalAlign.Start)
                Text('删除').fontFamily(this.appFontFamily).fontSize(14).fontColor('#FF4444')
                  .onClick(async () => {
                    AlertDialog.show({
                      title: '取消屏蔽',
                      message: '确定要取消屏蔽 ' + (u.name || u.uid) + '？',
                      primaryButton: {
                        value: '取消',
                        action: () => {}
                      },
                      secondaryButton: {
                        value: '解除屏蔽',
                        action: async () => {
                          await this.blockRepo.removeBlockUser(u.uid);
                          await this.loadBlockData();
                        }
                      },
                      cancel: () => {}
                    });
                  })
              }
              .width('100%').height(60).padding({ left: 16, right: 16 })
            })
          }
          .width('100%').backgroundColor(cardBg(this.isDark)).borderRadius(cardRadius(8))

          Text('屏蔽贴吧').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).width('100%').padding(16)

          Column() {
            if (this.blockedForums.length === 0) {
              Text('暂无屏蔽贴吧').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark))
                .width('100%').padding(16).textAlign(TextAlign.Center)
            }

            ForEach(this.blockedForums, (fname: string, idx: number) => {
              if (idx > 0) {
                Divider().height(1.5).color(dividerColor(this.isDark)).margin({ left: 16 })
              }
              Row() {
                Text(fname).fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark)).layoutWeight(1)
                Text('删除').fontFamily(this.appFontFamily).fontSize(14).fontColor('#FF4444')
                  .onClick(async () => {
                    AlertDialog.show({
                      title: '取消屏蔽',
                      message: '确定要取消屏蔽 ' + fname + '？',
                      primaryButton: {
                        value: '取消',
                        action: () => {}
                      },
                      secondaryButton: {
                        value: '解除屏蔽',
                        action: async () => {
                          await this.blockRepo.removeBlockForum(fname);
                          await this.loadBlockData();
                        }
                      },
                      cancel: () => {}
                    });
                  })
              }
              .width('100%').height(48).padding({ left: 16, right: 16 })
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
}
