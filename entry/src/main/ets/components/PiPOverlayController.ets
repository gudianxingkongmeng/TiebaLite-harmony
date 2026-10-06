import { NodeController, BuilderNode, FrameNode } from '@ohos.arkui.node';
import { UIContext } from '@ohos.arkui.UIContext';

export class PiPOverlayArgs {
  isMuted: boolean = false;
  onToggleMute: () => void = () => {};
}

@Builder
function pipMuteContent(args: PiPOverlayArgs) {
  Stack() {
    Column() {
      Row() {
        Blank()
        Column() {
          Image(args.isMuted ? $r('app.media.ic_volume_off') : $r('app.media.ic_volume_on'))
            .width(18).height(18).fillColor('#FFFFFF')
        }
        .width(36).height(36).borderRadius(18)
        .backgroundColor('#66000000')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .hitTestBehavior(HitTestMode.Block)
        .onClick(() => {
          console.info('TiebaLite: pip overlay mute click, isMuted=' + args.isMuted);
          args.onToggleMute();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ top: 10, right: 52 })
    }
    .width('100%').height('100%')
    .alignItems(HorizontalAlign.End)
    .justifyContent(FlexAlign.Start)
    .hitTestBehavior(HitTestMode.Transparent)
  }
  .width('100%')
  .height('100%')
}

export default class PiPOverlayNode extends NodeController {
  private builderNode: BuilderNode<[PiPOverlayArgs]> | null = null;
  private args: PiPOverlayArgs = new PiPOverlayArgs();

  setArgs(partial: Partial<PiPOverlayArgs>): void {
    if (partial.isMuted !== undefined) this.args.isMuted = partial.isMuted;
    if (partial.onToggleMute !== undefined) this.args.onToggleMute = partial.onToggleMute;
    if (this.builderNode) {
      try {
        this.builderNode.update(this.args);
      } catch (e) {
        console.error('TiebaLite: pip overlay update failed: ' + JSON.stringify(e));
      }
    }
  }

  reset(): void {
    this.builderNode = null;
    this.args = new PiPOverlayArgs();
  }

  makeNode(uiContext: UIContext): FrameNode | null {
    const builderNode = new BuilderNode<[PiPOverlayArgs]>(uiContext);
    this.builderNode = builderNode;
    try {
      builderNode.build(wrapBuilder<[PiPOverlayArgs]>(pipMuteContent), this.args);
    } catch (e) {
      console.error('TiebaLite: pip overlay build failed: ' + JSON.stringify(e));
    }
    const node = builderNode.getFrameNode();
    console.info('TiebaLite: pip overlay makeNode frameNode=' + (node ? 'ok' : 'null'));
    return node;
  }
}
