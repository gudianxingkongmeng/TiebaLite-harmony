import { Dict } from '../types/Dict';
import { TiebaApi } from '../api/TiebaApi';
import ITiebaApi from '../api/ITiebaApi';
import PreferencesManager from '../storage/PreferencesManager';

const HISTORY_PREF_KEY = 'search_history_list';

export default class SearchRepository {
  private static instance: SearchRepository;
  private api: ITiebaApi;

  private constructor() {
    this.api = TiebaApi.getInstance();
  }

  static getInstance(): SearchRepository {
    if (!SearchRepository.instance) {
      SearchRepository.instance = new SearchRepository();
    }
    return SearchRepository.instance;
  }

  async searchForum(keyword: string): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.searchForum(keyword, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async searchThread(keyword: string, page: number, sortMode: number, forumName?: string, filterType?: number): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.searchThread(keyword, page, sortMode, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      }, forumName, filterType);
    });
  }

  async searchUser(keyword: string): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.searchUser(keyword, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async searchPost(keyword: string, forumName: string, page: number, sortMode: number, onlyThread?: string): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.searchPost(keyword, forumName, page, sortMode, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      }, onlyThread);
    });
  }

  async getSuggestions(keyword: string): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.searchSuggestions(keyword, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async clearSearchHistory(): Promise<void> {
    const prefs = PreferencesManager.getInstance();
    if (prefs) {
      try { await prefs.putString(HISTORY_PREF_KEY, '[]'); } catch (_e) {}
    }
  }

  async deleteSearchHistory(keyword: string): Promise<void> {
    const prefs = PreferencesManager.getInstance();
    if (!prefs) return;
    try {
      const raw = await prefs.getString(HISTORY_PREF_KEY, '[]');
      const list = JSON.parse(raw) as string[];
      const filtered = list.filter((k) => k !== keyword);
      await prefs.putString(HISTORY_PREF_KEY, JSON.stringify(filtered));
    } catch (e) {
      console.error('TiebaLite: deleteSearchHistory failed: ' + String(e));
    }
  }

  async saveSearchHistory(keyword: string): Promise<void> {
    const prefs = PreferencesManager.getInstance();
    if (!prefs) return;
    try {
      const raw = await prefs.getString(HISTORY_PREF_KEY, '[]');
      const list = JSON.parse(raw) as string[];
      const filtered = list.filter((k) => k !== keyword);
      filtered.unshift(keyword);
      const trimmed = filtered.slice(0, 20);
      await prefs.putString(HISTORY_PREF_KEY, JSON.stringify(trimmed));
    } catch (e) {
      console.error('TiebaLite: saveSearchHistory failed: ' + String(e));
    }
  }

  async getSearchHistory(): Promise<string[]> {
    const prefs = PreferencesManager.getInstance();
    if (!prefs) return [];
    try {
      const raw = await prefs.getString(HISTORY_PREF_KEY, '[]');
      return JSON.parse(raw) as string[];
    } catch (e) {
      console.error('TiebaLite: getSearchHistory failed: ' + String(e));
    }
    return [];
  }
}
