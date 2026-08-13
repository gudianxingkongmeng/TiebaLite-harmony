import DatabaseManager from '../storage/DatabaseManager';

export default class BlockRepository {
  private static instance: BlockRepository;
  private blockKeywords: string[] = [];
  private blockUids: number[] = [];
  private blockForums: string[] = [];
  private loaded: boolean = false;
  private loading: Promise<void> | null = null;

  static getInstance(): BlockRepository {
    if (!BlockRepository.instance) {
      BlockRepository.instance = new BlockRepository();
    }
    return BlockRepository.instance;
  }

  async ensureLoaded(): Promise<void> {
    if (this.loaded) return;
    if (!this.loading) {
      this.loading = this.loadBlockRules().then(() => {
        this.loaded = true;
      });
    }
    return this.loading;
  }

  async loadBlockRules(): Promise<void> {
    const db = DatabaseManager.getInstance();

    const kwRs = await db.query('SELECT keyword FROM block_keyword WHERE whitelisted=0');
    this.blockKeywords = [];
    while (kwRs.goToNextRow()) {
      this.blockKeywords.push(kwRs.getString(kwRs.getColumnIndex('keyword')));
    }
    kwRs.close();

    const userRs = await db.query('SELECT uid FROM block_user WHERE whitelisted=0');
    this.blockUids = [];
    while (userRs.goToNextRow()) {
      this.blockUids.push(userRs.getLong(userRs.getColumnIndex('uid')));
    }
    userRs.close();

    const forumRs = await db.query('SELECT name FROM block_forum');
    this.blockForums = [];
    while (forumRs.goToNextRow()) {
      this.blockForums.push(forumRs.getString(forumRs.getColumnIndex('name')));
    }
    forumRs.close();
  }

  async ensureBlockUidsLoaded(): Promise<void> {
    await this.ensureLoaded();
  }

  isContentBlocked(title: string, content: string): boolean {
    const text = (title + ' ' + content).toLowerCase();
    for (const kw of this.blockKeywords) {
      if (text.includes(kw.toLowerCase())) return true;
    }
    return false;
  }

  isUserBlocked(uid: number): boolean {
    return this.blockUids.includes(uid);
  }

  isForumBlocked(forumName: string): boolean {
    return this.blockForums.includes(forumName);
  }

  /**
   * 判断帖子是否应被屏蔽:贴吧名、作者、标题、摘要任一命中即屏蔽。
   * uid 支持 number 或字符串数字。
   */
  isThreadBlocked(forumName: string, uid: number | string | undefined, title: string, abstract: string): boolean {
    if (forumName && this.isForumBlocked(forumName)) return true;
    const uidNum = Number(uid);
    if (uidNum > 0 && this.isUserBlocked(uidNum)) return true;
    return this.isContentBlocked(title, abstract);
  }

  /**
   * 判断楼层/楼中楼是否应被屏蔽:作者命中或内容命中关键词。
   */
  isPostBlocked(uid: number | string | undefined, content: string): boolean {
    const uidNum = Number(uid);
    if (uidNum > 0 && this.isUserBlocked(uidNum)) return true;
    return this.isContentBlocked('', content);
  }

  async addBlockKeyword(keyword: string): Promise<void> {
    await this.ensureLoaded();
    await DatabaseManager.getInstance().executeSql(
      'INSERT INTO block_keyword (keyword, isRegex, whitelisted) VALUES (?, 0, 0)',
      [keyword]
    );
    if (this.blockKeywords.indexOf(keyword) < 0) this.blockKeywords.push(keyword);
  }

  async removeBlockKeyword(keyword: string): Promise<void> {
    await this.ensureLoaded();
    await DatabaseManager.getInstance().executeSql(
      'DELETE FROM block_keyword WHERE keyword=?', [keyword]
    );
    this.blockKeywords = this.blockKeywords.filter(k => k !== keyword);
  }

  async addBlockUser(uid: number, name: string): Promise<void> {
    await this.ensureLoaded();
    await DatabaseManager.getInstance().executeSql(
      'INSERT OR REPLACE INTO block_user (uid, name, whitelisted) VALUES (?, ?, 0)',
      [uid, name]
    );
    if (this.blockUids.indexOf(uid) < 0) this.blockUids.push(uid);
  }

  async removeBlockUser(uid: number): Promise<void> {
    await this.ensureLoaded();
    await DatabaseManager.getInstance().executeSql(
      'DELETE FROM block_user WHERE uid=?', [uid]
    );
    this.blockUids = this.blockUids.filter(u => u !== uid);
  }

  async addBlockForum(name: string): Promise<void> {
    await this.ensureLoaded();
    await DatabaseManager.getInstance().executeSql(
      'INSERT INTO block_forum (name) VALUES (?)', [name]
    );
    if (this.blockForums.indexOf(name) < 0) this.blockForums.push(name);
  }

  async removeBlockForum(name: string): Promise<void> {
    await this.ensureLoaded();
    await DatabaseManager.getInstance().executeSql(
      'DELETE FROM block_forum WHERE name=?', [name]
    );
    this.blockForums = this.blockForums.filter(f => f !== name);
  }
}
