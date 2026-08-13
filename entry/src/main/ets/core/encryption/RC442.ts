export default class RC442 {
  private s: number[] = [];

  setup(key: number[]): void {
    this.s = [];
    for (let i = 0; i < 256; i++) {
      this.s[i] = i;
    }
    let j = 0;
    for (let i = 0; i < 256; i++) {
      j = (j + this.s[i] + key[i % key.length]) % 256;
      const temp = this.s[i];
      this.s[i] = this.s[j];
      this.s[j] = temp;
    }
  }

  crypt(src: number[]): number[] {
    const dest: number[] = [];
    let i = 0, j = 0;
    for (let k = 0; k < src.length; k++) {
      i = (i + 1) % 256;
      j = (j + this.s[i]) % 256;
      const temp = this.s[i];
      this.s[i] = this.s[j];
      this.s[j] = temp;
      const keyByte = this.s[(this.s[i] + this.s[j]) % 256] ^ 0x42;
      dest.push(src[k] ^ keyByte);
    }
    return dest;
  }

  static encrypt(key: number[], data: number[]): number[] {
    const rc = new RC442();
    rc.setup(key);
    return rc.crypt(data);
  }

  static decrypt(key: number[], data: number[]): number[] {
    return RC442.encrypt(key, data);
  }
}
