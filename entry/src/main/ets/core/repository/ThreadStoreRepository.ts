import { Dict } from '../types/Dict';
import { TiebaApi } from '../api/TiebaApi';
import ITiebaApi from '../api/ITiebaApi';

export default class ThreadStoreRepository {
  private static instance: ThreadStoreRepository;
  private api: ITiebaApi;

  private constructor() {
    this.api = TiebaApi.getInstance();
  }

  static getInstance(): ThreadStoreRepository {
    if (!ThreadStoreRepository.instance) {
      ThreadStoreRepository.instance = new ThreadStoreRepository();
    }
    return ThreadStoreRepository.instance;
  }

  async loadStores(page: number): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.threadStore(page, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async addStore(threadId: number, postId: number): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.addStore(threadId, postId, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async removeStore(threadId: number): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.removeStore(threadId, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }
}
