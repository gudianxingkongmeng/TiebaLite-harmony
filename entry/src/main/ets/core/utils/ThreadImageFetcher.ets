import { Dict } from '../types/Dict';
import PbPageRepository, { PicPageInfo, PicPageItem } from '../repository/PbPageRepository';

export class PhotoUrlCache {
  static map: Map<string, string[]> = new Map();
  static pending: Map<string, Promise<ThreadImageCollectResult>> = new Map();
  static subs: Map<string, Array<(all: string[]) => void>> = new Map();
}

export interface ThreadImageCollectResult {
  all: string[];
  pidOrder: number[];
  pidCounts: Map<number, number>;
}

export default class ThreadImageFetcher {
  private static repo: PbPageRepository = PbPageRepository.getInstance();

  static fetch(threadId: number, totalPage: number, onProgress?: (all: string[]) => void): Promise<ThreadImageCollectResult> {
    const key = String(threadId);
    if (onProgress) {
      const subs = PhotoUrlCache.subs.get(key) || [];
      subs.push(onProgress);
      PhotoUrlCache.subs.set(key, subs);
    }
    const existing = PhotoUrlCache.pending.get(key);
    if (existing) return existing;
    const emit = (all: string[]): void => ThreadImageFetcher.emitProgress(key, all);
    const task = ThreadImageFetcher.collect(threadId, totalPage, emit);
    PhotoUrlCache.pending.set(key, task);
    return task;
  }

  static fetchWindow(threadId: number, forumId: number, forumName: string, picId: string, picIndex: number, prev: boolean): Promise<PicPageInfo> {
    return ThreadImageFetcher.repo.getPicPageInfo(forumId, forumName, threadId, picId, picIndex, prev)
      .catch((e: Error) => {
        console.warn('TiebaLite: [PHOTO] picPage window failed ' + String(e));
        const empty: PicPageInfo = { amount: 0, items: [] };
        return empty;
      });
  }

  static getPicIdFromUrl(url: string): string {
    let u = url;
    const q = u.indexOf('?');
    if (q >= 0) u = u.substring(0, q);
    const slash = u.lastIndexOf('/');
    let name = slash >= 0 ? u.substring(slash + 1) : u;
    const dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    return name;
  }

  private static emitProgress(key: string, all: string[]): void {
    const subs = PhotoUrlCache.subs.get(key);
    if (!subs || subs.length === 0) return;
    for (const s of subs) s(all.slice());
  }

  private static async collect(threadId: number, totalPage: number, onProgress?: (all: string[]) => void): Promise<ThreadImageCollectResult> {
    const key = String(threadId);
    try {
      const all: string[] = [];
      const pidOrder: number[] = [];
      const pidCounts: Map<number, number> = new Map();
      let maxPage = Math.max(totalPage, 1);
      let first: Dict | null = null;
      try {
        first = await ThreadImageFetcher.repo.loadThreadPage(threadId, 1, false, null);
      } catch (e) {
        console.warn('TiebaLite: [PHOTO] first page failed ' + String(e));
      }
      if (first) {
        const pageInfo = (first.page || (first.data as Dict)?.page || {}) as Dict;
        const respTotal = Number(pageInfo.totalPage || pageInfo.total_page || 0);
        if (respTotal > maxPage) maxPage = respTotal;
        ThreadImageFetcher.collectPage(first, all, pidOrder, pidCounts);
      }
      if (maxPage <= 0) maxPage = 10;
      maxPage = Math.min(maxPage, 300);
      const BATCH = 5;
      let page = 2;
      while (page <= maxPage) {
        const end = Math.min(page + BATCH - 1, maxPage);
        const tasks: Promise<Dict | null>[] = [];
        for (let p = page; p <= end; p++) {
          tasks.push(ThreadImageFetcher.safeLoadPage(threadId, p));
        }
        const results: (Dict | null)[] = await Promise.all(tasks);
        for (const data of results) {
          if (data) ThreadImageFetcher.collectPage(data, all, pidOrder, pidCounts);
        }
        if (onProgress) onProgress(all);
        page = end + 1;
      }
      const res: ThreadImageCollectResult = { all: all, pidOrder: pidOrder, pidCounts: pidCounts };
      if (all.length > 0) PhotoUrlCache.map.set(key, all);
      return res;
    } finally {
      PhotoUrlCache.pending.delete(key);
      PhotoUrlCache.subs.delete(key);
    }
  }

  private static async safeLoadPage(threadId: number, page: number): Promise<Dict | null> {
    try {
      return await ThreadImageFetcher.repo.loadThreadPage(threadId, page, false, null);
    } catch (e) {
      console.warn('TiebaLite: [PHOTO] page ' + page + ' failed ' + String(e));
      return null;
    }
  }

  private static collectPage(data: Dict, all: string[], pidOrder: number[], pidCounts: Map<number, number>): void {
    const raw = data.post_list || (data.data as Dict)?.post_list || [];
    if (!Array.isArray(raw) || raw.length === 0) return;
    for (const post of raw as Dict[]) {
      if (!post || typeof post !== 'object') continue;
      const pid = Number(post.id || post.pid || post.post_id || 0);
      const urls = ThreadImageFetcher.extractImageUrls(post.content as Dict[]);
      if (urls.length === 0) continue;
      if (pid > 0) {
        if (!pidCounts.has(pid)) pidOrder.push(pid);
        pidCounts.set(pid, (pidCounts.get(pid) || 0) + urls.length);
      }
      for (const u of urls) all.push(u);
    }
  }

  private static extractImageUrls(content: Dict[]): string[] {
    const urls: string[] = [];
    if (!Array.isArray(content)) return urls;
    for (const item of content) {
      const t = Number(item.type);
      if (t === 1 || t === 3 || t === 20) {
        const src = String(item.originSrc || item.src || item.origin_src || item.cdn_src || item.c || '');
        if (src) urls.push(src.startsWith('http://') ? 'https://' + src.substring(7) : src);
      }
    }
    return urls;
  }
}
