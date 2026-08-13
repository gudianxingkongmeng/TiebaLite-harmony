import { Dict } from '../types/Dict';
import { TiebaApi } from '../api/TiebaApi';
import ITiebaApi from '../api/ITiebaApi';
import DatabaseManager from '../storage/DatabaseManager';
import AccountManager from '../auth/AccountManager';

export default class HomeRepository {
  private static instance: HomeRepository;
  private api: ITiebaApi;

  private constructor() {
    this.api = TiebaApi.getInstance();
  }

  static getInstance(): HomeRepository {
    if (!HomeRepository.instance) {
      HomeRepository.instance = new HomeRepository();
    }
    return HomeRepository.instance;
  }

  async loadHomeFeed(page: number): Promise<Dict> {
    return new Promise<Dict>((resolve, reject) => {
      this.api.personalized(0, page, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async loadRecommendedForums(): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.forumRecommend({
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async loadLikedForumsFromDb(): Promise<Dict[]> {
    const account = AccountManager.getInstance().getCurrentAccountSync();
    if (!account) return [];
    return DatabaseManager.getInstance().queryLikedForums(account.uid) as unknown as Dict[];
  }

  async fetchMessageCount(): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.msg({
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }
}
