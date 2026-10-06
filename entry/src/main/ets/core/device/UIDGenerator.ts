import MD5 from '../encryption/MD5';

export default class UIDGenerator {
  static async generateCuid(androidId: string): Promise<string> {
    const cuid = (await MD5.hash('com.baidu' + androidId)).toUpperCase();
    return cuid + '|000000000000000';
  }

  static async generateCuidGalaxy2(androidId: string): Promise<string> {
    const cuid = (await MD5.hash('com.baidu' + androidId)).toUpperCase();
    return cuid + '|000000000000000';
  }

  static generateClientId(): string {
    return 'wappc_' + Date.now() + '_' + Math.floor(Math.random() * 1000);
  }

  static generateHexString(length: number): string {
    let result = '';
    const hexChars = '0123456789abcdef';
    for (let i = 0; i < length; i++) {
      result += hexChars[Math.floor(Math.random() * 16)];
    }
    return result;
  }

  static generateImei(): string {
    return '000000000000000';
  }

  static async generateAndroidId(): Promise<string> {
    return (await MD5.hash(Date.now().toString() + Math.random().toString())).substring(0, 16);
  }

  static generateSampleId(): string {
    return Math.random().toString(36).substring(2, 15);
  }

  static generateBaiduId(): string {
    return this.generateHexString(32);
  }

  static async generateAid(cuid: string): Promise<string> {
    return (await MD5.hash(cuid + 'tieba')).substring(8, 24);
  }
}
