import fs from '@ohos.file.fs';
import { common } from '@kit.AbilityKit';

interface CacheEntry {
  data: string;
  expiry: number;
}

export default class FileCache {
  private cacheDir: string;

  constructor(context: common.Context) {
    this.cacheDir = context.cacheDir;
  }

  private getPath(key: string): string {
    return `${this.cacheDir}/cache_${this.sanitizeKey(key)}.json`;
  }

  private sanitizeKey(key: string): string {
    return key.replace(/[^a-zA-Z0-9_-]/g, '_').substring(0, 100);
  }

  async put(key: string, data: string, ttlMs: number = 3600000): Promise<void> {
    const entry: CacheEntry = {
      data: data,
      expiry: Date.now() + ttlMs
    };
    const path = this.getPath(key);
    try {
      const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
      fs.writeSync(file.fd, JSON.stringify(entry));
      fs.closeSync(file);
    } catch (e) {
    }
  }

  async get(key: string): Promise<string | null> {
    const path = this.getPath(key);
    try {
      if (!fs.accessSync(path)) return null;
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const buf = new ArrayBuffer(1024 * 1024);
      const len = fs.readSync(file.fd, buf);
      fs.closeSync(file);
      const text = String.fromCharCode(...new Uint8Array(buf.slice(0, len)));
      const entry: CacheEntry = JSON.parse(text);
      if (Date.now() > entry.expiry) {
        this.remove(key);
        return null;
      }
      return entry.data;
    } catch (e) {
      return null;
    }
  }

  remove(key: string): void {
    try {
      fs.unlinkSync(this.getPath(key));
    } catch (e) {}
  }

  clear(): void {
    try {
      const dir = fs.listFileSync(this.cacheDir);
      for (const file of dir) {
        if (file.startsWith('cache_')) {
          fs.unlinkSync(`${this.cacheDir}/${file}`);
        }
      }
    } catch (e) {}
  }
}
