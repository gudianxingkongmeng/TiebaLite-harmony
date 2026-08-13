export default class VideoProgressStore {
  private static map: Map<string, number> = new Map();

  static save(url: string, sec: number): void {
    if (!url || sec <= 0) return;
    VideoProgressStore.map.set(url, sec);
  }

  static get(url: string): number {
    const v = VideoProgressStore.map.get(url);
    return v !== undefined ? v : 0;
  }

  static clear(url: string): void {
    VideoProgressStore.map.delete(url);
  }
}
