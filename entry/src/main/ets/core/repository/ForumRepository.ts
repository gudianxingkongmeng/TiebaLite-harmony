import { Dict } from '../types/Dict';
import { TiebaApi } from '../api/TiebaApi';
import ITiebaApi from '../api/ITiebaApi';
import DatabaseManager from '../storage/DatabaseManager';
import AccountManager from '../auth/AccountManager';

interface ForumCacheEntry {
  data: Dict;
  timestamp: number;
}

export default class ForumRepository {
  private static instance: ForumRepository;
  private api: ITiebaApi;
  private forumCache: Map<string, ForumCacheEntry> = new Map();

  private constructor() {
    this.api = TiebaApi.getInstance();
  }

  static getInstance(): ForumRepository {
    if (!ForumRepository.instance) {
      ForumRepository.instance = new ForumRepository();
    }
    return ForumRepository.instance;
  }

  clearCache(): void {
    this.forumCache.clear();
  }

  async loadFrsPage(forumName: string, page: number, sortType: number, loadType: number = 0, tabId: number = 0): Promise<Dict> {
    const cacheKey = `frs_${forumName}_${page}_${sortType}_${loadType}_${tabId}`;
    const cached = this.forumCache.get(cacheKey);
    if (cached && Date.now() - cached.timestamp < 30000) {
      return cached.data;
    }

    return new Promise((resolve, reject) => {
      this.api.frsPage(forumName, page, loadType, sortType, tabId, {
        onSuccess: (data) => {
          this.forumCache.set(cacheKey, { data, timestamp: Date.now() });
          resolve(data);
        },
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async loadGoodFrsPage(forumName: string, page: number): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.frsPage(forumName, page, 1, 0, 0, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async loadGeneralTabList(forumId: number, forumName: string, tabId: number, tabName: string, tabType: number, isGeneralTab: number, page: number, sortType: number, lastThreadId: number): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.generalTabList(forumId, forumName, tabId, tabName, tabType, isGeneralTab, page, sortType, lastThreadId, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async getForumDetail(forumId: number): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.getForumDetail(forumId, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async likeForum(forumId: number, forumName: string): Promise<Dict> {
    const account = AccountManager.getInstance().getCurrentAccountSync();
    if (!account) throw new Error('Not logged in');

    return new Promise((resolve, reject) => {
      this.api.likeForum(forumId, forumName, account.tbs, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async unlikeForum(forumId: number, forumName: string): Promise<Dict> {
    const account = AccountManager.getInstance().getCurrentAccountSync();
    if (!account) throw new Error('Not logged in');

    return new Promise((resolve, reject) => {
      this.api.unlikeForum(forumId, forumName, account.tbs, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async signForum(forumId: number, forumName: string): Promise<Dict> {
    const account = AccountManager.getInstance().getCurrentAccountSync();
    if (!account) throw new Error('Not logged in');

    return new Promise((resolve, reject) => {
      this.api.sign(forumId, forumName, account.tbs, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => {
          if (code === 300001 || code === 300002 || code === 160002 || code === 2001 || code === 101016) {
            resolve({ error_code: String(code), error_msg: msg });
          } else {
            reject({ code, msg });
          }
        }
      });
    });
  }

  async getForumList(): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.getForumDetail(0, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async loadForumRule(forumId: number): Promise<Dict | null> {
    return new Promise((resolve, reject) => {
      this.api.forumRuleDetail(forumId, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }
}
