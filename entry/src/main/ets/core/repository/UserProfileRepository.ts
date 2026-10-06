import { Dict } from '../types/Dict';
import { TiebaApi } from '../api/TiebaApi';
import ITiebaApi from '../api/ITiebaApi';
import DatabaseManager from '../storage/DatabaseManager';
import AccountManager from '../auth/AccountManager';
import { HttpClient } from '../network/HttpClient';
import { encodeProfileReq, decodeProfileRes } from '../../proto/ProfileProto';
import { UserProfileInfo } from '../../model/UserProfileModels';

export default class UserProfileRepository {
  private static instance: UserProfileRepository;
  private api: ITiebaApi;

  private constructor() {
    this.api = TiebaApi.getInstance();
  }

  static getInstance(): UserProfileRepository {
    if (!UserProfileRepository.instance) {
      UserProfileRepository.instance = new UserProfileRepository();
    }
    return UserProfileRepository.instance;
  }

  async loadProfile(uid: number): Promise<Dict> {
    const rawHasStats = (data: Dict): boolean => {
      const d = (data?.data || data) as Dict;
      const u = d.user as Dict || {};
      const c = d.creator as Dict || {};
      const up = d.user_profile as Dict || {};
      const p = d.profile as Dict || {};
      const check = (o: Dict, ...keys: string[]): boolean => keys.some((k) => {
        const v = o[k];
        return v !== undefined && v !== null;
      });
      for (const o of [d, u, c, up, p]) {
        if (check(o, 'thread', 'threadNum', 'thread_num', 'thread_count', 'tiezi', 'post_num', 'post', 'postCount', 'post_count', 'pcount', 'posts', 'threads', 'postNum', 'postnum')) return true;
        if (check(o, 'fans', 'fansNum', 'fans_num', 'follower_count', 'followers', 'follower', 'fansCount', 'fans_count', 'fcount', 'fanNum', 'fannum')) return true;
        if (check(o, 'follow', 'followNum', 'follow_num', 'following_count', 'concernNum', 'concern_num', 'following', 'followCount', 'follow_count', 'flcount', 'flnum')) return true;
      }
      return false;
    };

    // Try mini API first; if data lacks stats, fall through
    try {
      const data = await this.loadStatsViaMiniApi(uid);
      if (rawHasStats(data)) return data;
    } catch (_e) {}

    try {
      const data = await new Promise<Dict>((resolve, reject) => {
        this.api.userProfile(uid, {
          onSuccess: (data) => resolve(data),
          onError: (code, msg) => reject({ code, msg })
        });
      });
      if (rawHasStats(data)) return data;
    } catch (_e2) {}

    // Last resort: getUserInfo
    return new Promise<Dict>((resolve, reject) => {
      this.api.getUserInfo(uid, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  /**
   * Load profile stats using protobuf API (same as postUserLikeProtobuf pattern)
   */
  async loadProfileProto(uid: number): Promise<Dict> {
    const data = await new Promise<Dict>((resolve, reject) => {
      this.api.userProfile(uid, {
        onSuccess: (data) => {
          console.warn('TiebaLite-WARN: userProfile topKeys=' + Object.keys(data).join(','));
          const d = (data?.data || data) as Dict;
          console.warn('TiebaLite-WARN: userProfile dataKeys=' + Object.keys(d).join(','));
          if (d.user) {
            console.warn('TiebaLite-WARN: userProfile userKeys=' + Object.keys(d.user as Dict).join(','));
          }
          resolve(data);
        },
        onError: (code, msg) => reject({ code, msg })
      });
    });
    const d = (data?.data || data) as Dict;
    const user = d.user as Dict || {};
    const hasStats = (user['post_num'] !== undefined || user['fans_num'] !== undefined || user['concern_num'] !== undefined);
    console.warn('TiebaLite-WARN: hasStats=' + hasStats + ' post_num=' + JSON.stringify(user['post_num']) + ' fans_num=' + JSON.stringify(user['fans_num']) + ' concern_num=' + JSON.stringify(user['concern_num']));
    if (hasStats) return data;
    throw new Error('userProfile response has no stats keys');
  }

  async loadProfileProtobufDirect(uid: number): Promise<UserProfileInfo> {
    const bytes = encodeProfileReq({ uid: uid, portrait: '' });
    const resBytes = await HttpClient.getInstance().postUserLikeProtobuf('/c/u/user/profile', bytes, 303012);
    return decodeProfileRes(resBytes);
  }

  async loadStatsViaMiniApi(uid: number): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.profile(uid, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async loadStatsViaUserInfo(uid: number): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.getUserInfo(uid, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async loadUserPosts(uid: number, page: number, isThread: boolean): Promise<Dict> {
    const tryMiniApi = (): Promise<Dict> => {
      return new Promise((resolve, reject) => {
        const api = this.api as any;
        if (api.postMiniApi) {
          api.postMiniApi('/c/u/feed/userpost', {
            uid: String(uid),
            pn: String(page),
            rn: '20',
            is_thread: isThread ? '1' : '0'
          }, {
            onSuccess: (data: Dict) => {
              console.info('TiebaLite: userPost miniApi resp keys=' + Object.keys(data).join(',') + ' err=' + data.error_code);
              const d = (data.data as Dict) || data;
              const errCode = data.error_code;
              if (errCode !== undefined && errCode !== null && String(errCode) !== '0' && String(errCode) !== '300000') {
                resolve({ data: [] as Object });
                return;
              }
              const keys = ['post_list', 'postList', 'thread_list', 'threadList', 'reply_list', 'replyList', 'list', 'data_list', 'dataList', 'items', 'feeds', 'posts', 'threads', 'postInfoList', 'post_info_list'];
              let found = false;
              for (const k of keys) { if (d[k] || data[k]) { found = true; break; } }
              if (found) resolve(data);
              else {
                let arr: Dict[] = [];
                for (const k of Object.keys(d)) { if (Array.isArray(d[k]) && (d[k] as Object[]).length > 0) arr.push(...d[k] as Dict[]); }
                if (arr.length > 0) resolve({ data: { items: arr } });
                else resolve({ data: [] as Object });
              }
            },
            onError: (code: number, msg: string) => {
              console.info('TiebaLite: userPost miniApi failed code=' + code);
              resolve({ data: [] as Object });
            }
          });
        } else {
          resolve({ data: [] as Object });
        }
      });
    };

    try {
      const data = await new Promise<Dict>((resolve, reject) => {
        this.api.userPost(uid, page, isThread, {
          onSuccess: (resp) => {
            const d = (resp.data as Dict) || resp;
            const dd = (d.data as Dict) || d;
            console.info('TiebaLite: userPost proto resp dKeys=' + Object.keys(dd).join(',') + ' topKeys=' + Object.keys(resp).join(',') + ' err=' + resp.error_code);
            const errCode = resp.error_code;
            if (errCode !== undefined && errCode !== null && String(errCode) !== '0' && String(errCode) !== '300000') {
              reject({ code: errCode, msg: resp.error_msg || '' });
              return;
            }
            // Find any array in the response at any level
            const keys = ['post_list', 'postList', 'thread_list', 'threadList', 'reply_list', 'replyList', 'list', 'data_list', 'dataList', 'items', 'feeds', 'posts', 'threads', 'postInfoList', 'post_info_list', 'threadInfoList', 'thread_info_list'];
            // Check dd, d, resp
            for (const src of [dd, d, resp]) {
              for (const k of keys) {
                const v = src[k];
                if (Array.isArray(v)) { resolve(resp); return; }
              }
            }
            // Also check if dd or d itself is an array
            if (Array.isArray(dd) && dd.length > 0) { resolve(resp); return; }
            if (Array.isArray(d) && d.length > 0) { resolve(resp); return; }
            // Any array at all
            for (const src of [dd, d, resp]) {
              for (const k of Object.keys(src)) {
                if (Array.isArray(src[k]) && (src[k] as Object[]).length > 0) { resolve(resp); return; }
              }
            }
            reject({ code: -2, msg: 'no known keys' });
          },
          onError: (code, msg) => reject({ code, msg })
        });
      });
      return data;
    } catch (e) {
      console.info('TiebaLite: userPost proto failed, trying mini API. err=' + JSON.stringify(e));
      return tryMiniApi();
    }
  }

  async followUser(portrait: string): Promise<Dict> {
    const account = AccountManager.getInstance().getCurrentAccountSync();
    if (!account) throw new Error('Not logged in');

    return new Promise((resolve, reject) => {
      this.api.follow(portrait, account.tbs, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async unfollowUser(portrait: string): Promise<Dict> {
    const account = AccountManager.getInstance().getCurrentAccountSync();
    if (!account) throw new Error('Not logged in');

    return new Promise((resolve, reject) => {
      this.api.unfollow(portrait, account.tbs, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async loadUserLikedForums(uid: number, page: number): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.userLikeForum(uid, page, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }
}
