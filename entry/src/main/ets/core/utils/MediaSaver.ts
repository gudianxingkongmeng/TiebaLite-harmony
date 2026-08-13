import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
import { fileUri, picker } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';

export default class MediaSaver {
  static readonly ALBUM_NAME: string = 'tieba lite';

  static detectExt(data: ArrayBuffer, fallback: string): string {
    const bytes = new Uint8Array(data);
    const b0 = bytes[0];
    const b1 = bytes[1];
    if (b0 === 0xFF && b1 === 0xD8 && bytes[2] === 0xFF) return 'jpg';
    if (b0 === 0x89 && b1 === 0x50 && bytes[2] === 0x4E && bytes[3] === 0x47) return 'png';
    if (b0 === 0x47 && b1 === 0x49 && bytes[2] === 0x46) return 'gif';
    if (b0 === 0x42 && b1 === 0x4D) return 'bmp';
    if (b0 === 0x52 && b1 === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46 &&
      bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50) return 'webp';
    if (b0 === 0x1A && b1 === 0x45 && bytes[2] === 0xDF && bytes[3] === 0xA3) return 'webm';
    if (bytes[4] === 0x66 && bytes[5] === 0x74 && bytes[6] === 0x79 && bytes[7] === 0x70) return 'mp4';
    return fallback;
  }

  static async saveToAlbum(context: common.UIAbilityContext, data: ArrayBuffer,
    photoType: photoAccessHelper.PhotoType, ext: string, title: string): Promise<void> {
    const realExt = MediaSaver.detectExt(data, ext);
    let realType = photoType;
    const imageExts = ['jpg', 'png', 'gif', 'webp', 'bmp'];
    const videoExts = ['mp4', 'webm', '3gp', 'mov', 'mkv', 'avi'];
    if (imageExts.indexOf(realExt) >= 0) {
      realType = photoAccessHelper.PhotoType.IMAGE;
    } else if (videoExts.indexOf(realExt) >= 0) {
      realType = photoAccessHelper.PhotoType.VIDEO;
    }
    try {
      await MediaSaver.saveWithDialog(context, data, realType, realExt, title);
    } catch (e) {
      if (String(e).indexOf('canceled') >= 0) {
        throw e;
      }
      console.warn('TiebaLite: save dialog failed, fallback to picker: ' + String(e));
      await MediaSaver.saveWithPicker(context, data, realType, realExt, title);
    }
  }

  private static async saveWithDialog(context: common.UIAbilityContext, data: ArrayBuffer,
    realType: photoAccessHelper.PhotoType, realExt: string, title: string): Promise<void> {
    const tmpPath = context.cacheDir + '/tmp_save_' + Date.now() + '.' + realExt;
    MediaSaver.writeTmp(tmpPath, data);
    try {
      const phHelper = photoAccessHelper.getPhotoAccessHelper(context);
      const config: photoAccessHelper.PhotoCreationConfig = {
        title: title,
        fileNameExtension: realExt,
        photoType: realType
      };
      const srcUri = fileUri.getUriFromPath(tmpPath);
      const result = await phHelper.showAssetsCreationDialog([srcUri], [config]);
      if (!result || result.length === 0) {
        throw new Error('canceled');
      }
      const desFile = fs.openSync(result[0], fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(desFile.fd, data);
      fs.closeSync(desFile);
    } finally {
      try { fs.unlinkSync(tmpPath); } catch (e) {}
    }
  }

  private static async saveWithPicker(context: common.UIAbilityContext, data: ArrayBuffer,
    _realType: photoAccessHelper.PhotoType, realExt: string, title: string): Promise<void> {
    const docPicker = new picker.DocumentViewPicker(context);
    const opts = new picker.DocumentSaveOptions();
    opts.newFileNames = [title + '.' + realExt];
    const uris = await docPicker.save(opts);
    if (!uris || uris.length === 0) {
      throw new Error('canceled');
    }
    const file = fs.openSync(uris[0], fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    fs.writeSync(file.fd, data);
    fs.closeSync(file);
  }

  private static writeTmp(tmpPath: string, data: ArrayBuffer): void {
    const file = fs.openSync(tmpPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
    fs.writeSync(file.fd, data);
    fs.closeSync(file);
  }
}
