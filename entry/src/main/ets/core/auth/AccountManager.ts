import { Dict } from '../types/Dict';
import DatabaseManager, { AccountEntity } from '../storage/DatabaseManager';
import PreferencesManager from '../storage/PreferencesManager';
import { TiebaApi } from '../api/TiebaApi';
import { ApiCallback } from '../api/ITiebaApi';

export class Account {
  uid: number;
  name: string;
  nickname: string;
  bduss: string;
  tbs: string;
  portrait: string;
  sToken: string;
  cookie: string;

  constructor(entity: AccountEntity) {
    this.uid = entity.uid;
    this.name = entity.name;
    this.nickname = entity.nickname;
    this.bduss = entity.bduss;
    this.tbs = entity.tbs;
    this.portrait = entity.portrait;
    this.sToken = entity.sToken;
    this.cookie = entity.cookie;
  }

  get isLoggedIn(): boolean {
    return this.bduss.length > 0;
  }
}

type AccountObserver = (account: Account | null) => void;

export default class AccountManager {
  private static instance: AccountManager;
  private currentAccount: Account | null = null;
  private accounts: Account[] = [];
  private observers: AccountObserver[] = [];

  private constructor() {}

  static getInstance(): AccountManager {
    if (!AccountManager.instance) {
      AccountManager.instance = new AccountManager();
    }
    return AccountManager.instance;
  }

  async init(): Promise<void> {
    console.info('TiebaLite: [LOGIN] AccountManager.init');
    const db = DatabaseManager.getInstance();
    const entities = await db.queryAccounts();
    this.accounts = entities.map(e => new Account(e));
    console.info('TiebaLite: [LOGIN] loaded ' + this.accounts.length + ' accounts');

    const prefs = PreferencesManager.getInstance();
    const lastUid = await prefs.getInt('account_uid', -1);
    if (lastUid >= 0) {
      const found = this.accounts.find(a => a.uid === lastUid);
      if (found) {
        this.currentAccount = found;
        console.info('TiebaLite: [LOGIN] restored account uid=' + lastUid);
      }
    }

    if (!this.currentAccount && this.accounts.length > 0) {
      this.currentAccount = this.accounts[0];
      console.info('TiebaLite: [LOGIN] using first account');
    }
  }

  getCurrentAccountSync(): Account | null {
    return this.currentAccount;
  }

  async getCurrentAccount(): Promise<Account | null> {
    return this.currentAccount;
  }

  getAllAccounts(): Account[] {
    return this.accounts;
  }

  async setCurrentAccount(account: Account): Promise<void> {
    this.currentAccount = account;
    const prefs = PreferencesManager.getInstance();
    await prefs.putInt('account_uid', account.uid);
    this.notifyObservers();
    console.info('TiebaLite: [LOGIN] switched to account uid=' + account.uid);
  }

  async addAccount(bduss: string, sToken: string): Promise<Account | null> {
    console.info('TiebaLite: [LOGIN] addAccount bduss=' + bduss.substring(0, 10) + '...');
    try {
      const userInfo = await this.fetchUserInfo(bduss, sToken);
      if (!userInfo) {
        console.error('TiebaLite: [LOGIN] fetchUserInfo returned null');
        return null;
      }

      const uid = userInfo.uid as number;
      const name = userInfo.name as string;
      const nickname = (userInfo.nickname as string) || (userInfo.name as string);
      const tbs = userInfo.tbs as string || '';
      const portrait = userInfo.portrait as string || '';
      const sex = userInfo.sex as number || 0;

      console.info('TiebaLite: [LOGIN] userInfo uid=' + uid + ' name=' + name + ' nickname=' + nickname);

      const entity = new AccountEntity();
      entity.uid = uid;
      entity.name = name;
      entity.nickname = nickname;
      entity.bduss = bduss;
      entity.sToken = sToken;
      entity.tbs = tbs;
      entity.portrait = portrait;
      entity.cookie = `BDUSS=${bduss}; STOKEN=${sToken}`;
      entity.sex = sex;
      entity.lastUpdate = Date.now();

      const db = DatabaseManager.getInstance();
      await db.upsertAccount(entity);

      const account = new Account(entity);
      const existingIdx = this.accounts.findIndex(a => a.uid === account.uid);
      if (existingIdx >= 0) {
        this.accounts[existingIdx] = account;
      } else {
        this.accounts.push(account);
      }

      await this.setCurrentAccount(account);
      console.info('TiebaLite: [LOGIN] account saved and set as current');
      return account;
    } catch (e) {
      console.error('TiebaLite: [LOGIN] addAccount exception:', String(e));
      return null;
    }
  }

  async removeAccount(uid: number): Promise<void> {
    const db = DatabaseManager.getInstance();
    await db.deleteAccount(uid);
    this.accounts = this.accounts.filter(a => a.uid !== uid);
    if (this.currentAccount?.uid === uid) {
      if (this.accounts.length > 0) {
        await this.setCurrentAccount(this.accounts[0]);
      } else {
        this.currentAccount = null;
        this.notifyObservers();
      }
    }
  }

  async logout(): Promise<void> {
    this.currentAccount = null;
    const prefs = PreferencesManager.getInstance();
    await prefs.remove('account_uid');
    this.notifyObservers();
  }

  isLoggedIn(): boolean {
    return this.currentAccount !== null && this.currentAccount.bduss.length > 0;
  }

  onAccountChange(observer: AccountObserver): void {
    this.observers.push(observer);
  }

  private notifyObservers(): void {
    for (const obs of this.observers) {
      obs(this.currentAccount);
    }
  }

  private async fetchUserInfo(bduss: string, sToken: string): Promise<Dict | null> {
    console.info('TiebaLite: [LOGIN] fetchUserInfo calling /c/s/login');
    try {
      const loginResult = await new Promise<Dict>((resolve, reject) => {
        TiebaApi.getInstance().login(bduss, sToken, {
          onSuccess: (data) => resolve(data),
          onError: (code, msg) => reject(new Error(msg || 'Login API error code=' + code))
        });
      });

      console.info('TiebaLite: [LOGIN] /c/s/login response: ' + JSON.stringify(loginResult).substring(0, 500));

      const errorCode = loginResult.error_code as string | number | undefined;
      if (errorCode !== undefined && errorCode !== '0' && errorCode !== 0) {
        console.error('TiebaLite: [LOGIN] Login API error_code=' + JSON.stringify(errorCode) + ' msg=' + loginResult.error_msg);
        return null;
      }

      const user = loginResult.user as Dict;
      const anti = loginResult.anti as Dict;
      if (!user) {
        console.error('TiebaLite: [LOGIN] Login response missing user field');
        return null;
      }

      console.info('TiebaLite: [LOGIN] login user=' + JSON.stringify(user) + ' anti=' + JSON.stringify(anti));

      let nickname = '';
      let tiebaUid = '';
      console.info('TiebaLite: [LOGIN] calling /c/s/initNickname');
      try {
        const nickResult = await new Promise<Dict>((resolve, reject) => {
          TiebaApi.getInstance().initNickName(bduss, sToken, {
            onSuccess: (data) => resolve(data),
            onError: (code, msg) => {
              console.warn('TiebaLite: [LOGIN] initNickname error code=' + code + ' msg=' + msg);
              reject(new Error(msg));
            }
          });
        });

        console.info('TiebaLite: [LOGIN] /c/s/initNickname response: ' + JSON.stringify(nickResult).substring(0, 300));

        const nickErrorCode = nickResult.error_code as string | number | undefined;
        if (nickErrorCode === undefined || nickErrorCode === '0' || nickErrorCode === 0) {
          const userInfo = nickResult.user_info as Dict;
          if (userInfo) {
            nickname = userInfo.name_show as string || '';
            tiebaUid = userInfo.tieba_uid as string || '';
            console.info('TiebaLite: [LOGIN] nickname=' + nickname + ' tiebaUid=' + tiebaUid);
          }
        }
      } catch (e) {
        console.info('TiebaLite: [LOGIN] initNickname failed (non-fatal): ' + String(e));
      }

      return {
        uid: parseInt(String(user.id || '0')),
        name: user.name || '',
        portrait: user.portrait || '',
        tbs: anti?.tbs || '',
        nickname: nickname || user.name || '',
        tiebaUid: tiebaUid,
        sex: user.sex || 0
      };
    } catch (e) {
      console.error('TiebaLite: [LOGIN] fetchUserInfo exception:', String(e));
      return null;
    }
  }
}
