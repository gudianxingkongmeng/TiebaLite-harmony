import http from '@ohos.net.http';

const b64Cache: Record<string, string> = {};
const failCache: Record<string, boolean> = {};

function bufToBase64(buf: ArrayBuffer): string {
  const bytes: Uint8Array = new Uint8Array(buf);
  const chars: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  let result: string = '';
  const len: number = bytes.length;
  for (let i = 0; i < len; i += 3) {
    const b1: number = bytes[i];
    const b2: number = i + 1 < len ? bytes[i + 1] : 0;
    const b3: number = i + 2 < len ? bytes[i + 2] : 0;
    const triple: number = (b1 << 16) | (b2 << 8) | b3;
    result += chars[(triple >> 18) & 0x3F];
    result += chars[(triple >> 12) & 0x3F];
    result += chars[(triple >> 6) & 0x3F];
    result += chars[triple & 0x3F];
  }
  const mod: number = len % 3;
  if (mod === 1) result = result.substring(0, result.length - 2) + '==';
  if (mod === 2) result = result.substring(0, result.length - 1) + '=';
  return result;
}

@Component
export default struct EmojiImage {
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @Prop url: string = '';
  @Prop emojiText: string = '';
  @State src: string = '';
  @State failed: boolean = false;
  @State imgErr: boolean = false;

  aboutToAppear(): void {
    if (b64Cache[this.url]) {
      this.src = b64Cache[this.url];
      return;
    }
    if (failCache[this.url]) {
      this.failed = true;
      return;
    }
    const httpUrl: string = this.url.replace('https://', 'http://');
    this.src = httpUrl;
    this.doBase64Load();
  }

  async doBase64Load(): Promise<void> {
    try {
      const currentUrl: string = this.url.replace('https://', 'http://');
      const req = http.createHttp();
      const resp = await req.request(currentUrl, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      });
      req.destroy();
      if (resp.responseCode === 200) {
        const buf: ArrayBuffer = resp.result as ArrayBuffer;
        if (buf && buf.byteLength > 0) {
          const b64: string = 'data:image/png;base64,' + bufToBase64(buf);
          b64Cache[this.url] = b64;
          this.src = b64;
          this.imgErr = false;
          return;
        }
      }
    } catch (e) {
      console.error('TiebaLite: EmojiDL err ' + JSON.stringify(e) + ' ' + this.url.substring(0, 60));
    }
    failCache[this.url] = true;
    this.failed = true;
  }

  build() {
    if (this.src && !this.imgErr) {
      Image(this.src)
        .width(20).height(20)
        .objectFit(ImageFit.Contain)
        .interpolation(ImageInterpolation.High)
        .onError(() => { this.imgErr = true; })
    } else if (this.failed && this.emojiText) {
      Text(this.emojiText)
        .fontFamily(this.appFontFamily).fontSize(12)
    } else {
      Image('')
        .width(20).height(20)
    }
  }
}
