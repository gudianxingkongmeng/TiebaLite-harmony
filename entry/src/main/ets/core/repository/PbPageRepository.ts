import { Dict } from '../types/Dict';
import { TiebaApi } from '../api/TiebaApi';
import ITiebaApi from '../api/ITiebaApi';
import AccountManager from '../auth/AccountManager';

interface ThreadCacheEntry {
  data: Dict;
  timestamp: number;
}

export interface PicPageItem {
  url: string;
  overallIndex: number;
  picId: string;
}

export interface PicPageInfo {
  amount: number;
  items: PicPageItem[];
}

function getPicIdFromUrl(url: string): string {
  let u = url;
  const q = u.indexOf('?');
  if (q >= 0) u = u.substring(0, q);
  const slash = u.lastIndexOf('/');
  let name = slash >= 0 ? u.substring(slash + 1) : u;
  const dot = name.lastIndexOf('.');
  if (dot > 0) name = name.substring(0, dot);
  return name;
}

function toHttps(url: string): string {
  return url.startsWith('http://') ? 'https://' + url.substring(7) : url;
}

export default class PbPageRepository {
  private static readonly THREAD_CACHE_TTL = 5 * 60 * 1000;
  private static instance: PbPageRepository;
  private api: ITiebaApi;
  private threadCache: Map<string, ThreadCacheEntry> = new Map();

  private constructor() {
    this.api = TiebaApi.getInstance();
  }

  static getInstance(): PbPageRepository {
    if (!PbPageRepository.instance) {
      PbPageRepository.instance = new PbPageRepository();
    }
    return PbPageRepository.instance;
  }

  async loadThreadPage(threadId: number, page: number, seeLz: boolean, sortType: number | null): Promise<Dict> {
    const cacheKey = `${threadId}_${page}_${seeLz}_${sortType}`;
    const cached = this.threadCache.get(cacheKey);
    if (cached && Date.now() - cached.timestamp < PbPageRepository.THREAD_CACHE_TTL) {
      return cached.data;
    }
    return new Promise((resolve, reject) => {
      this.api.pbPage(threadId, page, null, seeLz, sortType, {
        onSuccess: (data) => {
          this.threadCache.set(cacheKey, { data, timestamp: Date.now() });
          resolve(data);
        },
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  clearThreadCache(): void {
    this.threadCache.clear();
  }

  async loadFloorPage(threadId: number, postId: number, forumId: number, page: number): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.pbFloor(threadId, postId, forumId, page, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async likePost(threadId: number, postId: number): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.opAgree(threadId, postId, 0, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async dislikePost(threadId: number, postId: number): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.disagree(threadId, postId, 1, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async deletePost(forumId: number, forumName: string, threadId: number, postId: number): Promise<Dict> {
    const account = AccountManager.getInstance().getCurrentAccountSync();
    return new Promise((resolve, reject) => {
      this.api.delPost(forumId, forumName, threadId, postId, account?.tbs || '', {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async deleteThread(forumId: number, forumName: string, threadId: number): Promise<Dict> {
    const account = AccountManager.getInstance().getCurrentAccountSync();
    return new Promise((resolve, reject) => {
      this.api.delThread(forumId, forumName, threadId, account?.tbs || '', {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async votePoll(forumId: number, threadId: number, option: string): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.addPollPost(forumId, threadId, option, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async getPicPageInfo(forumId: number, forumName: string, threadId: number, picId: string, picIndex: number, prev: boolean): Promise<PicPageInfo> {
    return new Promise((resolve, reject) => {
      this.api.picPage(forumId, forumName, threadId, picId, picIndex, prev, {
        onSuccess: (data) => {
          const amount = Number(data['pic_amount']);
          const items: PicPageItem[] = [];
          if (amount > 0) {
            const list: Dict[] = Array.isArray(data['pic_list']) ? data['pic_list'] as Dict[] : [];
            for (const item of list) {
              const img: Dict = (item['img'] || {}) as Dict;
              const orig: Dict = (img['original'] || {}) as Dict;
              const medium: Dict = (img['medium'] || {}) as Dict;
              let url = String(orig['waterurl'] || orig['big_cdn_src'] || orig['original_src'] || orig['url'] || medium['waterurl'] || medium['big_cdn_src'] || medium['url'] || '');
              if (!url) continue;
              url = toHttps(url);
              const picId = String(orig['id'] || getPicIdFromUrl(url));
              const overallIndex = Number(item['overall_index']);
              items.push({ url: url, overallIndex: overallIndex > 0 ? overallIndex : items.length + 1, picId: picId });
            }
          }
          resolve({ amount: amount, items: items });
        },
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }
}
