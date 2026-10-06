import { Dict } from '../core/types/Dict';
import { blendWithBg, pageBg, cardBg, textPrimary, textSecondary, textTertiary, dividerColor, shadowColor } from '../core/utils/DataHelper';
import AddPostRepository from '../core/repository/AddPostRepository';

@Component
export default struct ReplySheet {
  @Prop threadId: number = 0;
  @Prop forumId: number = 0;
  @Prop forumName: string = '';
  @Prop postId: number = 0;
  @Prop subPostId: number = 0;
  @Prop replyUserId: number = 0;
  @Prop replyUserName: string = '';
  @State text: string = '';
  @State posting: boolean = false;
  @StorageLink('isDarkTheme') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  onSuccess?: (data: Dict) => void;
  onCancel?: () => void;

  build() {
    Column() {
      Row() {
        Text(this.replyUserName ? '回复 @' + this.replyUserName : '发表回复')
          .fontFamily(this.appFontFamily).fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(textPrimary(this.isDark))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Blank()
        Text('取消')
          .fontFamily(this.appFontFamily).fontSize(14)
          .fontColor(textTertiary(this.isDark))
          .padding({ left: 10, right: 2, top: 4, bottom: 4 })
          .onClick(() => { if (this.onCancel) this.onCancel(); })
      }
      .width('100%')
      .margin({ bottom: 12 })

      TextArea({ text: this.text, placeholder: '输入回复内容...' })
        .width('100%')
        .height(120)
        .backgroundColor(pageBg(this.isDark))
        .borderRadius(12)
        .padding(12)
        .fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
        .placeholderColor(textTertiary(this.isDark))
        .onChange((v: string) => { this.text = v; })

      Row() {
        if (this.text.length > 0) {
          Text(String(this.text.length) + '/10000')
            .fontFamily(this.appFontFamily).fontSize(11)
            .fontColor(textTertiary(this.isDark))
        }
        Blank()
        Button(this.posting ? '发送中...' : '发送')
          .width(84)
          .height(38)
          .backgroundColor(this.text.length > 0 ? '#4477E0' : textTertiary(this.isDark))
          .fontColor('#FFFFFF')
          .fontSize(15)
          .borderRadius(19)
          .enabled(this.text.length > 0 && !this.posting)
          .onClick(() => {
            if (this.posting || this.text.length === 0) return;
            this.posting = true;
            this.doPost();
          })
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .padding(16)
    .padding({ bottom: 20 })
    .width('100%')
    .backgroundColor(cardBg(this.isDark))
    .borderRadius({ topLeft: 16, topRight: 16 })
  }

  private async doPost(): Promise<void> {
    try {
      const result: Dict = await AddPostRepository.getInstance().replyToThread(
        this.forumId, this.forumName, this.threadId, this.text,
        this.postId > 0 ? this.postId : undefined,
        this.subPostId > 0 ? this.subPostId : undefined
      );
      if (this.onSuccess) this.onSuccess(result);
    } catch (e) {
      console.error('Reply failed:', e);
    } finally {
      this.posting = false;
    }
  }
}