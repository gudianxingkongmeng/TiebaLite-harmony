import { Dict } from '../types/Dict';
import PreferencesManager from '../storage/PreferencesManager';
import AccountManager from '../auth/AccountManager';
import { getStr } from './DataHelper';

const RECENT_FORUMS_KEY = 'recent_forums_json';
const MAX_RECENT_FORUMS = 30;

/** 获取当前账号 uid，未登录返回 '' */
function getUid(): string {
  try {
    const account = AccountManager.getInstance().getCurrentAccountSync();
    return account ? String(account.uid || '') : '';
  } catch (_e) {
    return '';
  }
}

/** 从存储中读取当前账号的最近贴吧列表 */
function getAccountList(): Dict[] {
  try {
    const raw = AppStorage.Get<string>('recentForumsJson') || '';
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed)) return parsed as Dict[];
    const all = parsed as Dict;
    const uid = getUid();
    const list = all[uid] as Dict[] | undefined;
    if (Array.isArray(list) && list.length > 0) return list;
    const globalList = all[''] as Dict[] | undefined;
    if (Array.isArray(globalList)) return globalList;
    return [];
  } catch (_e) {
    return [];
  }
}

/** 将当前账号的最近贴吧列表写入存储 */
function setAccountList(list: Dict[]): void {
  try {
    const raw = AppStorage.Get<string>('recentForumsJson') || '';
    let all: Dict = {};
    try {
      if (raw) {
        const parsed = JSON.parse(raw);
        if (Array.isArray(parsed)) {
          all = {};
          all[''] = parsed;
        } else {
          all = parsed as Dict;
        }
      }
    } catch (_e) {
      all = {};
    }
    const uid = getUid();
    all[uid] = list;
    const json = JSON.stringify(all);
    AppStorage.Set<string>('recentForumsJson', json);
    try {
      PreferencesManager.getInstance().putString(RECENT_FORUMS_KEY, json);
    } catch (_e) {}
  } catch (_e) {}
}

/** 获取当前账号的最近贴吧列表 */
export function getRecentForums(): Dict[] {
  if (!getUid()) return [];
  return getAccountList();
}

export function saveRecentForum(forum: Dict): void {
  if (!forum) return;
  const name = getStr(forum, 'name', 'forumName', 'forum_name');
  const id = getStr(forum, 'id', 'forum_id', 'forumId');
  if (!name) return;
  if (!getUid()) return;

  let list = getAccountList();
  list = list.filter((f: Dict) => {
    const fid = getStr(f, 'id', 'forum_id', 'forumId');
    const fname = getStr(f, 'name', 'forumName', 'forum_name');
    return fid !== id && fname !== name;
  });

  const entry: Dict = { name: name, id: id };
  const avatar = getStr(forum, 'avatar', 'forumAvatar');
  if (avatar) entry.avatar = avatar;
  list.unshift(entry);
  if (list.length > MAX_RECENT_FORUMS) list = list.slice(0, MAX_RECENT_FORUMS);
  setAccountList(list);
}

export function removeRecentForum(forum: Dict): void {
  if (!forum) return;
  const name = getStr(forum, 'name', 'forumName', 'forum_name');
  const id = getStr(forum, 'id', 'forum_id', 'forumId');
  if (!name) return;
  if (!getUid()) return;

  let list = getAccountList();
  list = list.filter((f: Dict) => {
    const fid = getStr(f, 'id', 'forum_id', 'forumId');
    const fname = getStr(f, 'name', 'forumName', 'forum_name');
    return fid !== id && fname !== name;
  });
  setAccountList(list);
}