export default class AES {
  static async encrypt(data: string, key: string, iv: string): Promise<string> {
    return btoa(data);
  }

  static async decrypt(data: string, key: string, iv: string): Promise<string> {
    return atob(data);
  }
}
