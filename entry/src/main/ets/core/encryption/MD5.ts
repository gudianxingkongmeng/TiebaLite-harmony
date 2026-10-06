import cryptoFramework from '@ohos.security.cryptoFramework';
import util from '@ohos.util';

let md5Lock: Promise<void> = Promise.resolve();

export default class MD5 {
  static async hash(str: string): Promise<string> {
    await md5Lock;
    let releaseLock: () => void;
    md5Lock = new Promise<void>((resolve) => { releaseLock = resolve; });
    try {
      const md = cryptoFramework.createMd('MD5');
      const encoder = new util.TextEncoder();
      const data = encoder.encodeInto(str);
      await md.update({ data: data });
      const digest = await md.digest();
      const bytes = digest.data as Uint8Array;
      let hex = '';
      for (let i = 0; i < bytes.length; i++) {
        hex += bytes[i].toString(16).padStart(2, '0');
      }
      return hex;
    } catch (e) {
      console.error('TiebaLite: MD5 hash error: ' + e);
      return '';
    } finally {
      releaseLock!();
    }
  }

  static async hashBytes(data: Uint8Array): Promise<string> {
    await md5Lock;
    let releaseLock: () => void;
    md5Lock = new Promise<void>((resolve) => { releaseLock = resolve; });
    try {
      const md = cryptoFramework.createMd('MD5');
      await md.update({ data: data });
      const digest = await md.digest();
      const bytes = digest.data as Uint8Array;
      let hex = '';
      for (let i = 0; i < bytes.length; i++) {
        hex += bytes[i].toString(16).padStart(2, '0');
      }
      return hex;
    } catch (e) {
      console.error('TiebaLite: MD5 hashBytes error: ' + e);
      return '';
    } finally {
      releaseLock!();
    }
  }
}