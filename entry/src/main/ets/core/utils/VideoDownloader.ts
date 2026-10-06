import http from '@ohos.net.http';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import util from '@ohos.util';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import MediaSaver from './MediaSaver';

export default class VideoDownloader {
  static async saveVideo(url: string, context: common.UIAbilityContext): Promise<void> {
    if (!url) return;
    let ext = 'mp4';
    const extMatch = url.match(/\.([a-zA-Z0-9]+)(\?.*)?$/);
    if (extMatch) {
      const rawExt = extMatch[1].toLowerCase();
      if (rawExt === 'mp4' || rawExt === 'webm' || rawExt === '3gp' || rawExt === 'mov' || rawExt === 'mkv' || rawExt === 'avi') {
        ext = rawExt;
      }
    }
    try {
      const httpRequest = http.createHttp();
      const resp = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        header: { 'User-Agent': 'bdtb for Android 12.52.1.0', 'Referer': 'https://tieba.baidu.com/' }
      });
      httpRequest.destroy();
      const data = resp.result as ArrayBuffer;
      if (resp.responseCode !== 200 || !data || data.byteLength === 0) {
        promptAction.showToast({ message: '下载失败' });
        return;
      }
      const head = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(data).slice(0, 64));
      if (head.indexOf('<html') >= 0 || head.indexOf('<!DOCTYPE') >= 0) {
        promptAction.showToast({ message: '下载失败' });
        return;
      }
      await MediaSaver.saveToAlbum(context, data, photoAccessHelper.PhotoType.VIDEO, ext, 'tieba_video_' + Date.now());
      promptAction.showToast({ message: '已保存到相册 tieba lite' });
    } catch (e) {
      console.error('TiebaLite: saveVideo error=' + String(e));
      promptAction.showToast({ message: (String(e).indexOf('canceled') >= 0) ? '已取消保存' : '保存失败' });
    }
  }
}
