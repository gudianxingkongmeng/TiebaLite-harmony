import { Dict } from '../types/Dict';
import ForumRepository from '../repository/ForumRepository';
import { getStr } from './DataHelper';

export class ForumAvatarCache {
  static map: Map<string, string> = new Map();
  static pending: Map<string, Promise<string>> = new Map();
}

export default class ForumAvatarFetcher {
  private static repo: ForumRepository = ForumRepository.getInstance();

  static get(forumName: string): Promise<string> {
    const key = forumName;
    const hit = ForumAvatarCache.map.get(key);
    if (hit) return Promise.resolve(hit);
    const pending = ForumAvatarCache.pending.get(key);
    if (pending) return pending;
    const task = ForumAvatarFetcher.fetch(key);
    ForumAvatarCache.pending.set(key, task);
    return task;
  }

  private static async fetch(forumName: string): Promise<string> {
    const key = forumName;
    try {
      const data: Dict = await ForumAvatarFetcher.repo.loadFrsPage(forumName, 1, 0, 0);
      if (!data || typeof data !== 'object') return '';
      const d = (data.data as Dict) || data;
      const forum = (d.forum as Dict) || {};
      let avatar = getStr(d, 'forumAvatar', 'forum_avatar', 'forumAvatarUrl', 'forum_avatar_url');
      if (!avatar) avatar = getStr(forum, 'avatar', 'head', 'forum_avatar', 'forumAvatar', 'icon', 'img', 'picture');
      if (avatar) ForumAvatarCache.map.set(key, avatar);
      return avatar;
    } catch (e) {
      console.warn('TiebaLite: [AVATAR] fetch forum avatar failed forum=' + forumName + ' err=' + String(e));
      return '';
    } finally {
      ForumAvatarCache.pending.delete(key);
    }
  }
}
