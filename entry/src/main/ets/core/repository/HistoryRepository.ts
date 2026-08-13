import DatabaseManager, { ThreadHistoryEntity } from '../storage/DatabaseManager';
import { Dict } from '../types/Dict';

export default class HistoryRepository {
  private static instance: HistoryRepository;

  static getInstance(): HistoryRepository {
    if (!HistoryRepository.instance) {
      HistoryRepository.instance = new HistoryRepository();
    }
    return HistoryRepository.instance;
  }

  async saveThreadHistory(info: Dict): Promise<void> {
    const entity = new ThreadHistoryEntity();
    entity.id = Number(info.id || info.tid || info.threadId || 0);
    entity.avatar = String(info.avatar || info.authorPortrait || info.author_portrait || '');
    entity.name = String(info.authorName || info.author_name || info.name || '');
    entity.forum = String(info.forumName || info.forum_name || info.forum || '');
    entity.title = String(info.title || '');
    entity.pid = Number(info.pid || info.firstPostId || 0);
    entity.timestamp = Date.now();
    const dataObj: Dict = {};
    for (const k of ['firstPostContent', 'first_post_content', 'media', 'imageUrls', 'videoInfo', 'video_info', 'agree', 'author', 'title', 'forumName', 'forum_name', 'forumId', 'forum_id', 'lastTimeInt', 'lastTime', 'last_time', 'lastTimeStr', 'last_time_str', 'createTime', 'create_time', 'replyNum', 'reply_num', 'shareNum', 'share_num', 'agreeNum', 'agree_num']) {
      if (info[k] !== undefined) dataObj[k] = info[k];
    }
    entity.data = JSON.stringify(dataObj);
    if (entity.id > 0) {
      await DatabaseManager.getInstance().upsertThreadHistory(entity);
    }
  }

  async getThreadHistories(): Promise<ThreadHistoryEntity[]> {
    return DatabaseManager.getInstance().getThreadHistories(50);
  }

  async deleteThreadHistory(id: number): Promise<void> {
    return DatabaseManager.getInstance().deleteThreadHistory(id);
  }

  async clearThreadHistories(): Promise<void> {
    await DatabaseManager.getInstance().executeSql('DELETE FROM thread_history');
  }

  async getForumHistories(): Promise<object[]> {
    const rs = await DatabaseManager.getInstance().query(
      'SELECT * FROM forum_history ORDER BY timestamp DESC LIMIT 50'
    );
    const histories: object[] = [];
    while (rs.goToNextRow()) {
      histories.push({
        id: rs.getLong(rs.getColumnIndex('id')),
        name: rs.getString(rs.getColumnIndex('name')),
        avatar: rs.getString(rs.getColumnIndex('avatar')),
        timestamp: rs.getLong(rs.getColumnIndex('timestamp'))
      });
    }
    rs.close();
    return histories;
  }

  async clearForumHistories(): Promise<void> {
    await DatabaseManager.getInstance().executeSql('DELETE FROM forum_history');
  }
}
