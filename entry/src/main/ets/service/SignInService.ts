import notification from '@ohos.notification';
import net from '@ohos.net.connection';
import AccountManager from '../core/auth/AccountManager';
import ForumRepository from '../core/repository/ForumRepository';
import PreferencesManager from '../core/storage/PreferencesManager';
import { TiebaApi } from '../core/api/TiebaApi';
import ITiebaApi from '../core/api/ITiebaApi';
import { getNum, getStr } from '../core/utils/DataHelper';
import { Dict } from '../core/types/Dict';

export default class SignInService {
  private static instance: SignInService;
  private api: ITiebaApi = TiebaApi.getInstance();

  static getInstance(): SignInService {
    if (!SignInService.instance) {
      SignInService.instance = new SignInService();
    }
    return SignInService.instance;
  }

  async tryAutoSignIn(): Promise<void> {
    try {
      const prefs = PreferencesManager.getInstance();
      const autoSign = await prefs.getBoolean('auto_sign', false);
      if (!autoSign) {
        console.info('TiebaLite: [sign] skip: auto_sign off');
        return;
      }

      const account = AccountManager.getInstance().getCurrentAccountSync();
      if (!account) {
        console.info('TiebaLite: [sign] skip: not logged in');
        return;
      }

      const signTime = await prefs.getInt('sign_time', 8);
      const now = new Date();
      if (now.getHours() < signTime) {
        console.info('TiebaLite: [sign] skip: hour ' + now.getHours() + ' < signTime ' + signTime);
        return;
      }

      const today = now.getFullYear() + '-' + (now.getMonth() + 1) + '-' + now.getDate();
      const lastDate = await prefs.getString('sign_last_date', '');
      const lastSuccess = await prefs.getString('sign_last_success', '');
      if (lastDate === today && lastSuccess === '1') {
        console.info('TiebaLite: [sign] skip: already done today ' + today);
        return;
      }

      const wifiOnly = await prefs.getBoolean('sign_wifi_only', false);
      if (wifiOnly) {
        const wifi = await this.isWifi();
        console.info('TiebaLite: [sign] wifiOnly on, isWifi=' + wifi);
        if (!wifi) return;
      }

      let successCount = 0;
      let failCount = 0;
      let unsignedCount = 0;
      const signedIds: number[] = [];
      try {
        const data = await this.fetchForumData();
        if (!data) {
          console.error('TiebaLite: [sign] forum list fetch returned null');
          return;
        }
        const forums = this.extractForums(data);
        const repo = ForumRepository.getInstance();
        for (const forum of forums) {
          const isSign = getNum(forum, 'is_sign', 'isSign', 'sign', 'signed');
          if (isSign > 0) continue;
          const forumId = Number(getNum(forum, 'id', 'forum_id', 'forumId') || getStr(forum, 'forum_id', 'forumId') || 0);
          if (forumId <= 0) continue;
          unsignedCount++;
          const forumName = getStr(forum, 'name', 'forumName', 'forum_name') || '';
          try {
            await repo.signForum(forumId, forumName);
            successCount++;
            signedIds.push(forumId);
          } catch (e) {
            failCount++;
            console.error('TiebaLite: [sign] forum ' + forumName + ' failed: ' + String(e));
          }
        }
      } catch (e) {
        console.error('TiebaLite: [sign] fetch or sign error: ' + String(e));
        return;
      }

      if (successCount > 0) {
        try {
          const prev = AppStorage.Get<Object[]>('signedForumIdsArr') ?? [];
          const merged = new Set<number>();
          for (const v of prev) {
            const n = Number(v);
            if (n > 0) merged.add(n);
          }
          for (const id of signedIds) {
            merged.add(id);
          }
          const arr: number[] = [];
          merged.forEach((v) => { arr.push(v); });
          AppStorage.SetOrCreate('signedForumIdsArr', arr as Object[]);
        } catch (e) {
          console.error('TiebaLite: [sign] update signed cache failed: ' + String(e));
        }
      }

      const allFailed = unsignedCount > 0 && successCount === 0;
      if (allFailed) {
        console.info('TiebaLite: [sign] all failed, no date recorded, will retry');
        return;
      }
      await prefs.putString('sign_last_date', today);
      await prefs.putString('sign_last_success', '1');
      console.info('TiebaLite: [sign] done today, success=' + successCount + ' fail=' + failCount + ' unsigned=' + unsignedCount);

      const signNotify = await prefs.getBoolean('sign_notify', false);
      if (successCount > 0 && signNotify) {
        await this.showNotification(successCount, failCount);
      }
    } catch (e) {
      console.error('TiebaLite: [sign] tryAutoSignIn error: ' + String(e));
    }
  }

  private async fetchForumData(): Promise<Dict | null> {
    try {
      return await new Promise<Dict>((resolve, reject) => {
        this.api.forumRecommend({
          onSuccess: (d) => resolve(d),
          onError: (code, msg) => reject({ code, msg })
        });
      });
    } catch (e) {
      console.info('TiebaLite: [sign] forumRecommend failed, trying userLikeForum');
      try {
        const account = AccountManager.getInstance().getCurrentAccountSync();
        if (!account) return null;
        const uid = Number(account.uid || 0);
        if (!uid) return null;
        return await new Promise<Dict>((resolve, reject) => {
          this.api.userLikeForum(uid, 1, {
            onSuccess: (d) => resolve(d),
            onError: (code, msg) => reject({ code, msg })
          });
        });
      } catch (e2) {
        console.error('TiebaLite: [sign] userLikeForum also failed: ' + String(e2));
        try {
          return await new Promise<Dict>((resolve, reject) => {
            this.api.forumRecommendNew(0, {
              onSuccess: (d) => resolve(d),
              onError: (code, msg) => reject({ code, msg })
            });
          });
        } catch (e3) {
          console.error('TiebaLite: [sign] all forum APIs failed: ' + String(e3));
          return null;
        }
      }
    }
  }

  private extractForums(data: Dict): Dict[] {
    if (!data) return [];
    const d = (data.data as Dict) || data;
    const candidates = ['forum_list', 'like_forum', 'list', 'forum', 'forums', 'data_list', 'follow_list', 'follow_forum', 'like_list'];
    for (const key of candidates) {
      if (d[key] && Array.isArray(d[key]) && (d[key] as Dict[]).length > 0) {
        return d[key] as Dict[];
      }
    }
    if (Array.isArray(data)) return data as Object as Dict[];
    if (Array.isArray(d)) return d as Object as Dict[];
    return [];
  }

  private async isWifi(): Promise<boolean> {
    try {
      const netHandle = await net.getDefaultNet();
      const caps = await net.getNetCapabilities(netHandle);
      return caps.bearerTypes.includes(net.NetBearType.BEARER_WIFI);
    } catch (e) {
      console.error('TiebaLite: [sign] wifi check failed: ' + String(e));
      return false;
    }
  }

  private async showNotification(success: number, fail: number): Promise<void> {
    try {
      await notification.publish({
        id: 1001,
        content: {
          contentType: notification.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: '贴吧签到',
            text: `签到完成：成功 ${success} 个，失败 ${fail} 个`
          }
        }
      });
    } catch (e) {
      console.error('TiebaLite: [sign] notification failed: ' + String(e));
    }
  }
}
