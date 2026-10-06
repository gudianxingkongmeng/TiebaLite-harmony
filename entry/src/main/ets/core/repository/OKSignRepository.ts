import { TiebaApi } from '../api/TiebaApi';
import ITiebaApi from '../api/ITiebaApi';
import DatabaseManager from '../storage/DatabaseManager';
import AccountManager from '../auth/AccountManager';

export default class OKSignRepository {
  private static instance: OKSignRepository;
  private api: ITiebaApi;

  private constructor() {
    this.api = TiebaApi.getInstance();
  }

  static getInstance(): OKSignRepository {
    if (!OKSignRepository.instance) {
      OKSignRepository.instance = new OKSignRepository();
    }
    return OKSignRepository.instance;
  }

  async signForum(forumId: number, forumName: string, tbs: string): Promise<void> {
    return new Promise((resolve, reject) => {
      this.api.sign(forumId, forumName, tbs, {
        onSuccess: () => {
          const account = AccountManager.getInstance().getCurrentAccountSync();
          if (account) {
            DatabaseManager.getInstance().executeSql(
              'UPDATE liked_forum SET sign=? WHERE id=? AND uid=?,
              [Date.now(), forumId, account.uid]
            );
          }
          resolve();
        },
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async signAllForums(): Promise<{ success: number; failed: number }> {
    const account = AccountManager.getInstance().getCurrentAccountSync();
    if (!account) throw new Error('Not logged in');

    const db = DatabaseManager.getInstance();
    const forums = await db.queryLikedForums(account.uid);

    let success = 0;
    let failed = 0;

    for (const forum of forums) {
      try {
        await new Promise<void>((resolve, reject) => {
          this.api.sign(forum.id, forum.name, account.tbs, {
            onSuccess: () => {
              db.executeSql(
                'UPDATE liked_forum SET sign=? WHERE id=? AND uid=?,
                [Date.now(), forum.id, account.uid]
              );
              resolve();
            },
            onError: () => reject(new Error('sign failed'))
          });
        });
        success++;
        await new Promise(r => setTimeout(r, 3500 + Math.random() * 4500));
      } catch (e) {
        failed++;
      }
    }

    return { success, failed };
  }
}
