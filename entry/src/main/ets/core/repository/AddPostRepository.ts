import { Dict } from '../types/Dict';
import { TiebaApi } from '../api/TiebaApi';
import ITiebaApi from '../api/ITiebaApi';
import AccountManager from '../auth/AccountManager';

export default class AddPostRepository {
  private static instance: AddPostRepository;
  private api: ITiebaApi;

  private constructor() {
    this.api = TiebaApi.getInstance();
  }

  static getInstance(): AddPostRepository {
    if (!AddPostRepository.instance) {
      AddPostRepository.instance = new AddPostRepository();
    }
    return AddPostRepository.instance;
  }

  async replyToThread(forumId: number, forumName: string, threadId: number, content: string, postId?: number, subPostId?: number, replyUserId?: number): Promise<Dict> {
    const account = AccountManager.getInstance().getCurrentAccountSync();
    if (!account) throw new Error('Not logged in');

    return new Promise((resolve, reject) => {
      this.api.addPost(content, forumId, forumName, threadId, account.tbs, {
        onSuccess: (data) => {
          resolve(data);
        },
        onError: (code, msg) => reject({ code, msg })
      }, postId, subPostId, replyUserId);
    });
  }

  async createThread(forumName: string, forumId: number, title: string, content: string, tabId: number = 0): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.addThread(content, forumName, forumId, title, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      }, tabId);
    });
  }
}
