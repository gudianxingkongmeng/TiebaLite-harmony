import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import AddPostRepository from '../../core/repository/AddPostRepository';
import { textPrimary, textSecondary, textTertiary, pageBg, cardBg, blendWithBg } from '../../core/utils/DataHelper';

@Entry
@Component
struct ReplyPage {
  @State text: string = '';
  @State posting: boolean = false;
  @State threadId: number = 0;
  @State forumId: number = 0;
  @State forumName: string = '';
  @State replyHint: string = '';
  @StorageLink('isDarkTheme') isDark: boolean = false;
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  @StorageLink('appFontFamily') appFontFamily: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.threadId = parseInt(params?.threadId || '0');
    this.forumId = parseInt(params?.forumId || '0');
    this.forumName = params?.forumName || '';
    this.replyHint = params?.replyHint || '';
  }

  build() {
    Column() {
      Row() {
        Button('取消').fontColor(textSecondary(this.isDark)).backgroundColor('transparent')
          .onClick(() => router.back())
        Blank()
        Text('回复').fontFamily(this.appFontFamily).fontSize(18).fontWeight(FontWeight.Bold)
        Blank()
        Button(this.posting ? '发表中...' : '发表')
          .fontColor(this.text.length > 0 ? '#FFFFFF' : textTertiary(this.isDark))
          .backgroundColor(this.text.length > 0 ? this.primaryColor : blendWithBg(this.primaryColor, 0.3, this.isDark))
          .borderRadius(16).height(32).padding({ left: 16, right: 16 })
          .enabled(this.text.length > 0 && !this.posting)
          .onClick(() => this.doPost())
      }
      .padding(12).width('100%')

      TextArea({ text: this.text, placeholder: this.replyHint || '输入回复...' })
        .width('100%').height(200).backgroundColor(pageBg(this.isDark)).borderRadius(12).padding(12)
        .onChange((v: string) => { this.text = v; })

      Text('请遵守社区规定').fontFamily(this.appFontFamily).fontSize(11).fontColor('#FF8800').width('100%').textAlign(TextAlign.Center).padding({ top: 4 })

      Blank()
    }
    .width('100%').height('100%').padding(16).backgroundColor(cardBg(this.isDark))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    
  }

  private async doPost(): Promise<void> {
    if (this.posting || !this.text.trim()) return;
    this.posting = true;
    try {
      await AddPostRepository.getInstance().replyToThread(
        this.forumId, this.forumName, this.threadId, this.text
      );
      promptAction.showToast({ message: '回复成功', duration: 1500 });
      router.back();
    } catch (e) {
      promptAction.showToast({ message: '回复失败', duration: 2000 });
    } finally {
      this.posting = false;
    }
  }
}
