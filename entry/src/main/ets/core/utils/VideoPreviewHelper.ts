export class VideoPreviewHelper {
  static clearActive(): void {
    AppStorage.SetOrCreate('previewActiveId', '');
    AppStorage.SetOrCreate('previewActiveVisible', false);
  }
}
