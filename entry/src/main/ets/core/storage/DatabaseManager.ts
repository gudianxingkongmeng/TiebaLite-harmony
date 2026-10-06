import relationalStore from '@ohos.data.relationalStore';
import { common } from '@kit.AbilityKit';

export type Dict = { [key: string]: Object };

export class AccountEntity {
  uid: number = 0;
  name: string = '';
  nickname: string = '';
  bduss: string = '';
  tbs: string = '';
  portrait: string = '';
  sToken: string = '';
  cookie: string = '';
  intro: string = '';
  sex: number = 0;
  fans: string = '';
  posts: string = '';
  threads: string = '';
  concerned: string = '';
  tbAge: number = 0;
  age: number = 0;
  birthdayShow: boolean = false;
  birthdayTime: number = 0;
  constellation: string = '';
  tiebaUid: string = '';
  zid: string = '';
  lastUpdate: number = 0;
  blockDays: number = 0;
}

export class ThreadHistoryEntity {
  id: number = 0;
  avatar: string = '';
  name: string = '';
  forum: string = '';
  title: string = '';
  isSeeLz: boolean = false;
  pid: number = 0;
  timestamp: number = 0;
  data: string = '';
}

export class ForumHistoryEntity {
  id: number = 0;
  name: string = '';
  avatar: string = '';
  timestamp: number = 0;
}

export class UserProfileEntity {
  uid: number = 0;
  portrait: string = '';
  name: string = '';
  nickname: string = '';
  tiebaUid: string = '';
  intro: string = '';
  sex: string = '';
  tbAge: string = '';
  address: string = '';
  following: boolean = false;
  thread: number = 0;
  post: number = 0;
  forum: number = 0;
  follow: number = 0;
  fans: number = 0;
  agree: number = 0;
  bazuDesc: string = '';
  newGod: string = '';
  privateForum: boolean = false;
  isOfficial: boolean = false;
  lastUpdate: number = 0;
  lastVisit: number = 0;
  blockDays: number = 0;
}

export class LikedForumEntity {
  id: number = 0;
  uid: number = 0;
  avatar: string = '';
  name: string = '';
  level: number = 0;
  sign: number = 0;
}

export class DraftEntity {
  threadId: number = 0;
  postId: number = 0;
  subpostId: number = 0;
  content: string = '';
}

export class SearchHistoryEntity {
  id: number = 0;
  keyword: string = '';
  timestamp: number = 0;
}

export class SearchPostHistoryEntity {
  id: number = 0;
  forumId: number = 0;
  keyword: string = '';
  timestamp: number = 0;
}

export class BlockKeywordEntity {
  id: number = 0;
  keyword: string = '';
  isRegex: boolean = false;
  whitelisted: boolean = false;
}

export class BlockUserEntity {
  uid: number = 0;
  name: string = '';
  whitelisted: boolean = false;
}

export class TimestampEntity {
  uid: number = 0;
  type: number = 0;
  time: number = 0;
}

export default class DatabaseManager {
  private static instance: DatabaseManager;
  private rdbStore?: relationalStore.RdbStore;
  private context: common.Context;

  private constructor(context: common.Context) {
    this.context = context;
  }

  static async init(context: common.Context): Promise<void> {
    if (!DatabaseManager.instance) {
      DatabaseManager.instance = new DatabaseManager(context);
      await DatabaseManager.instance.openDatabase();
    }
  }

  static getInstance(): DatabaseManager {
    return DatabaseManager.instance;
  }

  private async openDatabase(): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: 'tb_lite.db',
      securityLevel: relationalStore.SecurityLevel.S1
    };
    this.rdbStore = await relationalStore.getRdbStore(this.context, config);
    await this.createTables();
  }

  private async createTables(): Promise<void> {
    const sqls = [
      `CREATE TABLE IF NOT EXISTS account (
        uid INTEGER PRIMARY KEY,
        name TEXT NOT NULL DEFAULT '',
        nickname TEXT DEFAULT '',
        bduss TEXT NOT NULL DEFAULT '',
        tbs TEXT DEFAULT '',
        portrait TEXT DEFAULT '',
        sToken TEXT DEFAULT '',
        cookie TEXT DEFAULT '',
        intro TEXT DEFAULT '',
        sex INTEGER DEFAULT 0,
        fans TEXT DEFAULT '',
        posts TEXT DEFAULT '',
        threads TEXT DEFAULT '',
        concerned TEXT DEFAULT '',
        tbAge REAL DEFAULT 0,
        age INTEGER DEFAULT 0,
        birthdayShow INTEGER DEFAULT 0,
        birthdayTime INTEGER DEFAULT 0,
        constellation TEXT DEFAULT '',
        tiebaUid TEXT DEFAULT '',
        zid TEXT DEFAULT '',
        lastUpdate INTEGER DEFAULT 0,
        blockDays INTEGER DEFAULT 0
      )`,
      `CREATE TABLE IF NOT EXISTS thread_history (
        id INTEGER PRIMARY KEY,
        avatar TEXT DEFAULT '',
        name TEXT DEFAULT '',
        forum TEXT DEFAULT '',
        title TEXT DEFAULT '',
        isSeeLz INTEGER DEFAULT 0,
        pid INTEGER DEFAULT 0,
        timestamp INTEGER DEFAULT 0,
        data TEXT DEFAULT ''
      )`,
      `CREATE TABLE IF NOT EXISTS forum_history (
        id INTEGER PRIMARY KEY,
        name TEXT DEFAULT ,
        avatar TEXT DEFAULT ,
        timestamp INTEGER DEFAULT 0
      )`,
      `CREATE TABLE IF NOT EXISTS user_profile (
        uid INTEGER PRIMARY KEY,
        portrait TEXT DEFAULT ,
        name TEXT DEFAULT ,
        nickname TEXT DEFAULT ,
        tiebaUid TEXT DEFAULT ,
        intro TEXT DEFAULT ,
        sex TEXT DEFAULT ,
        tbAge TEXT DEFAULT ,
        address TEXT DEFAULT ,
        following INTEGER DEFAULT 0,
        thread INTEGER DEFAULT 0,
        post INTEGER DEFAULT 0,
        forum INTEGER DEFAULT 0,
        follow INTEGER DEFAULT 0,
        fans INTEGER DEFAULT 0,
        agree INTEGER DEFAULT 0,
        bazuDesc TEXT DEFAULT ,
        newGod TEXT DEFAULT ,
        privateForum INTEGER DEFAULT 0,
        isOfficial INTEGER DEFAULT 0,
        lastUpdate INTEGER DEFAULT 0,
        lastVisit INTEGER DEFAULT 0,
        blockDays INTEGER DEFAULT 0
      )`,
      `CREATE TABLE IF NOT EXISTS liked_forum (
        id INTEGER NOT NULL,
        uid INTEGER NOT NULL,
        avatar TEXT DEFAULT ,
        name TEXT DEFAULT ,
        level INTEGER DEFAULT 0,
        sign INTEGER DEFAULT 0,
        PRIMARY KEY (id, uid)
      )`,
      `CREATE TABLE IF NOT EXISTS draft (
        threadId INTEGER NOT NULL,
        postId INTEGER NOT NULL,
        subpostId INTEGER NOT NULL,
        content TEXT DEFAULT ,
        PRIMARY KEY (threadId, postId, subpostId)
      )`,
      `CREATE TABLE IF NOT EXISTS search_history (
        id INTEGER PRIMARY KEY,
        keyword TEXT DEFAULT ,
        timestamp INTEGER DEFAULT 0
      )`,
      `CREATE TABLE IF NOT EXISTS search_post_history (
        id INTEGER PRIMARY KEY,
        forumId INTEGER DEFAULT 0,
        keyword TEXT DEFAULT ,
        timestamp INTEGER DEFAULT 0
      )`,
      `CREATE TABLE IF NOT EXISTS block_keyword (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword TEXT NOT NULL,
        isRegex INTEGER DEFAULT 0,
        whitelisted INTEGER DEFAULT 0
      )`,
      `CREATE TABLE IF NOT EXISTS block_user (
        uid INTEGER PRIMARY KEY,
        name TEXT DEFAULT ,
        whitelisted INTEGER DEFAULT 0
      )`,
      `CREATE TABLE IF NOT EXISTS block_forum (
        name TEXT PRIMARY KEY
      )`,
      `CREATE TABLE IF NOT EXISTS top_forum (
        forumId INTEGER PRIMARY KEY
      )`,
      `CREATE TABLE IF NOT EXISTS timestamp (
        uid INTEGER NOT NULL,
        type INTEGER NOT NULL,
        time INTEGER DEFAULT 0,
        PRIMARY KEY (uid, type)
      )`,
      `CREATE INDEX IF NOT EXISTS idx_thread_history_ts ON thread_history(timestamp)`,
      `CREATE INDEX IF NOT EXISTS idx_forum_history_ts ON forum_history(timestamp)`,
      `CREATE INDEX IF NOT EXISTS idx_liked_forum_level ON liked_forum(level)`,
      `CREATE INDEX IF NOT EXISTS idx_search_history_ts ON search_history(timestamp)`,
      `CREATE INDEX IF NOT EXISTS idx_search_post_history_ts ON search_post_history(timestamp)`,
      `CREATE INDEX IF NOT EXISTS idx_block_keyword_white ON block_keyword(whitelisted)`,
      `CREATE INDEX IF NOT EXISTS idx_block_user_white ON block_user(whitelisted)`,
      `CREATE INDEX IF NOT EXISTS idx_user_profile_visit ON user_profile(lastVisit)`
    ];

    for (const sql of sqls) {
      await this.rdbStore!.executeSql(sql);
    }
  }

  async queryAccounts(): Promise<AccountEntity[]> {
    const predicates = new relationalStore.RdbPredicates('account');
    predicates.orderByDesc('lastUpdate');
    const resultSet = await this.rdbStore!.query(predicates, ['*']);
    const accounts: AccountEntity[] = [];
    while (resultSet.goToNextRow()) {
      accounts.push(this.rowToAccount(resultSet));
    }
    resultSet.close();
    return accounts;
  }

  async getAccount(uid: number): Promise<AccountEntity | null> {
    const predicates = new relationalStore.RdbPredicates('account');
    predicates.equalTo('uid', uid);
    const resultSet = await this.rdbStore!.query(predicates, ['*']);
    let account: AccountEntity | null = null;
    if (resultSet.goToFirstRow()) {
      account = this.rowToAccount(resultSet);
    }
    resultSet.close();
    return account;
  }

  async upsertAccount(account: AccountEntity): Promise<void> {
    const row = this.accountToRow(account);
    const predicates = new relationalStore.RdbPredicates('account');
    predicates.equalTo('uid', account.uid);
    try {
      const changed = await this.rdbStore!.update(row, predicates);
      if (changed === 0) {
        await this.rdbStore!.insert('account', row);
      }
    } catch (_e) {
      await this.rdbStore!.executeSql('DROP TABLE IF EXISTS account');
      await this.rdbStore!.executeSql(
        `CREATE TABLE IF NOT EXISTS account (
          uid INTEGER PRIMARY KEY,
          name TEXT NOT NULL DEFAULT '',
          nickname TEXT DEFAULT '',
          bduss TEXT NOT NULL DEFAULT '',
          tbs TEXT DEFAULT '',
          portrait TEXT DEFAULT '',
          sToken TEXT DEFAULT '',
          cookie TEXT DEFAULT '',
          intro TEXT DEFAULT '',
          sex INTEGER DEFAULT 0,
          fans TEXT DEFAULT '',
          posts TEXT DEFAULT '',
          threads TEXT DEFAULT '',
          concerned TEXT DEFAULT '',
          tbAge REAL DEFAULT 0,
          age INTEGER DEFAULT 0,
          birthdayShow INTEGER DEFAULT 0,
          birthdayTime INTEGER DEFAULT 0,
          constellation TEXT DEFAULT '',
          tiebaUid TEXT DEFAULT '',
          zid TEXT DEFAULT '',
          lastUpdate INTEGER DEFAULT 0,
          blockDays INTEGER DEFAULT 0
        )`
      );
      await this.rdbStore!.insert('account', row);
    }
  }

  async deleteAccount(uid: number): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('account');
    predicates.equalTo('uid', uid);
    await this.rdbStore!.delete(predicates);
  }

  async queryLikedForums(uid: number): Promise<LikedForumEntity[]> {
    const predicates = new relationalStore.RdbPredicates('liked_forum');
    predicates.equalTo('uid', uid);
    predicates.orderByDesc('level');
    const resultSet = await this.rdbStore!.query(predicates, ['*']);
    const forums: LikedForumEntity[] = [];
    while (resultSet.goToNextRow()) {
      forums.push(this.rowToLikedForum(resultSet));
    }
    resultSet.close();
    return forums;
  }

  async upsertLikedForum(forum: LikedForumEntity): Promise<void> {
    await this.rdbStore!.insert('liked_forum', {
      id: forum.id,
      uid: forum.uid,
      avatar: forum.avatar,
      name: forum.name,
      level: forum.level,
      sign: forum.sign
    });
  }

  async deleteLikedForum(uid: number, forumId: number): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('liked_forum');
    predicates.equalTo('uid', uid);
    predicates.equalTo('id', forumId);
    await this.rdbStore!.delete(predicates);
  }

  async deleteAllLikedForums(uid: number): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('liked_forum');
    predicates.equalTo('uid', uid);
    await this.rdbStore!.delete(predicates);
  }

  async upsertThreadHistory(history: ThreadHistoryEntity): Promise<void> {
    await this.rdbStore!.executeSql(
      'INSERT OR REPLACE INTO thread_history (id, avatar, name, forum, title, isSeeLz, pid, timestamp, data) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [history.id, history.avatar, history.name, history.forum, history.title, history.isSeeLz ? 1 : 0, history.pid, history.timestamp, history.data]
    );
  }

  async mergeThreadHistoryData(id: number, patch: Dict): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('thread_history');
    predicates.equalTo('id', id);
    const resultSet = await this.rdbStore!.query(predicates, ['*']);
    if (resultSet.goToNextRow()) {
      const h = new ThreadHistoryEntity();
      h.id = resultSet.getLong(resultSet.getColumnIndex('id'));
      h.avatar = resultSet.getString(resultSet.getColumnIndex('avatar'));
      h.name = resultSet.getString(resultSet.getColumnIndex('name'));
      h.forum = resultSet.getString(resultSet.getColumnIndex('forum'));
      h.title = resultSet.getString(resultSet.getColumnIndex('title'));
      h.isSeeLz = resultSet.getLong(resultSet.getColumnIndex('isSeeLz')) === 1;
      h.pid = resultSet.getLong(resultSet.getColumnIndex('pid'));
      h.timestamp = resultSet.getLong(resultSet.getColumnIndex('timestamp'));
      h.data = resultSet.getString(resultSet.getColumnIndex('data'));
      resultSet.close();
      if (h.data) {
        const merged: Dict = {};
        try {
          const parsed = JSON.parse(h.data) as Dict;
          for (const k of Object.keys(parsed)) merged[k] = parsed[k];
        } catch (_e) {}
        for (const k of Object.keys(patch)) merged[k] = patch[k];
        h.data = JSON.stringify(merged);
      } else {
        h.data = JSON.stringify(patch);
      }
      await this.upsertThreadHistory(h);
    } else {
      resultSet.close();
    }
  }

  async getThreadHistories(limit: number = 50): Promise<ThreadHistoryEntity[]> {
    const predicates = new relationalStore.RdbPredicates('thread_history');
    predicates.orderByDesc('timestamp');
    predicates.limitAs(limit);
    const resultSet = await this.rdbStore!.query(predicates, ['*']);
    const histories: ThreadHistoryEntity[] = [];
    while (resultSet.goToNextRow()) {
      const h = new ThreadHistoryEntity();
      h.id = resultSet.getLong(resultSet.getColumnIndex('id'));
      h.avatar = resultSet.getString(resultSet.getColumnIndex('avatar'));
      h.name = resultSet.getString(resultSet.getColumnIndex('name'));
      h.forum = resultSet.getString(resultSet.getColumnIndex('forum'));
      h.title = resultSet.getString(resultSet.getColumnIndex('title'));
      h.isSeeLz = resultSet.getLong(resultSet.getColumnIndex('isSeeLz')) === 1;
      h.pid = resultSet.getLong(resultSet.getColumnIndex('pid'));
      h.timestamp = resultSet.getLong(resultSet.getColumnIndex('timestamp'));
      h.data = resultSet.getString(resultSet.getColumnIndex('data'));
      histories.push(h);
    }
    resultSet.close();
    return histories;
  }

  async deleteThreadHistory(id: number): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('thread_history');
    predicates.equalTo('id', id);
    await this.rdbStore!.delete(predicates);
  }

  private rowToAccount(rs: relationalStore.ResultSet): AccountEntity {
    const a = new AccountEntity();
    a.uid = rs.getLong(rs.getColumnIndex('uid'));
    a.name = rs.getString(rs.getColumnIndex('name'));
    a.nickname = rs.getString(rs.getColumnIndex('nickname'));
    a.bduss = rs.getString(rs.getColumnIndex('bduss'));
    a.tbs = rs.getString(rs.getColumnIndex('tbs'));
    a.portrait = rs.getString(rs.getColumnIndex('portrait'));
    a.sToken = rs.getString(rs.getColumnIndex('sToken'));
    a.cookie = rs.getString(rs.getColumnIndex('cookie'));
    return a;
  }

  private accountToRow(a: AccountEntity): relationalStore.ValuesBucket {
    return {
      uid: a.uid,
      name: a.name,
      nickname: a.nickname,
      bduss: a.bduss,
      tbs: a.tbs,
      portrait: a.portrait,
      sToken: a.sToken,
      cookie: a.cookie,
      intro: a.intro,
      sex: a.sex,
      fans: a.fans,
      posts: a.posts,
      threads: a.threads,
      concerned: a.concerned,
      tbAge: a.tbAge,
      age: a.age,
      birthdayShow: a.birthdayShow ? 1 : 0,
      birthdayTime: a.birthdayTime,
      constellation: a.constellation,
      tiebaUid: a.tiebaUid,
      zid: a.zid,
      lastUpdate: Date.now(),
      blockDays: a.blockDays
    };
  }

  private rowToLikedForum(rs: relationalStore.ResultSet): LikedForumEntity {
    const f = new LikedForumEntity();
    f.id = rs.getLong(rs.getColumnIndex('id'));
    f.uid = rs.getLong(rs.getColumnIndex('uid'));
    f.avatar = rs.getString(rs.getColumnIndex('avatar'));
    f.name = rs.getString(rs.getColumnIndex('name'));
    f.level = rs.getLong(rs.getColumnIndex('level'));
    f.sign = rs.getLong(rs.getColumnIndex('sign'));
    return f;
  }

  async query(sql: string, bindArgs?: relationalStore.ValueType[]): Promise<relationalStore.ResultSet> {
    return await this.rdbStore!.querySql(sql, bindArgs);
  }

  async executeSql(sql: string, bindArgs?: relationalStore.ValueType[]): Promise<void> {
    await this.rdbStore!.executeSql(sql, bindArgs);
  }
}
