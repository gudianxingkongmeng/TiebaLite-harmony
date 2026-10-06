import { Dict } from '../types/Dict';
import PreferencesManager from '../storage/PreferencesManager';
import { getStr } from './DataHelper';

const RECENT_FORUMS_KEY = 'recent_forums_json';
const MAX_RECENT_FORUMS = 30;

export function saveRecentForum(forum: Dict): void {
  if (!forum) return;
  const name = getStr(forum, 'name', 'forumName', 'forum_name');
  const id = getStr(forum, 'id', 'forum_id', 'forumId');
  if (!name) return;

  let list: Dict[] = [];
  try {
    const raw = AppStorage.Get<string>('recentForumsJson') || '';
    if (raw) list = JSON.parse(raw) as Dict[];
  } catch (_e) {
    list = [];
  }

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

  const json = JSON.stringify(list);
  AppStorage.Set<string>('recentForumsJson', json);
  try {
    PreferencesManager.getInstance().putString(RECENT_FORUMS_KEY, json);
  } catch (_e) {}
}