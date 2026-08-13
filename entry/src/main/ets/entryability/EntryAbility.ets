import Ability from '@ohos.app.ability.UIAbility';
import Window from '@ohos.window';
import webview from '@ohos.web.webview';
import DatabaseManager from '../core/storage/DatabaseManager';
import PreferencesManager from '../core/storage/PreferencesManager';
import AccountManager from '../core/auth/AccountManager';
import DeviceFingerprint from '../core/device/DeviceFingerprint';
import ThemeProvider from '../core/theme/ThemeProvider';
import MessagePollingService from '../service/MessagePollingService';
import { setPendingDeepLink } from '../core/utils/DeepLinkHelper';
import { GripDetector } from '../core/utils/GripDetector';
import { pageBg } from '../core/utils/DataHelper';

function setDeepLink(page: string, k1: string, v1: string, k2: string, v2: string): void {
  let json: string = '{"page":"' + page + '","params":{';
  json += '"' + k1 + '":"' + v1 + '"';
  if (k2) json += ',"' + k2 + '":"' + v2 + '"';
  json += '}}';
  setPendingDeepLink(json);
  try { AppStorage.SetOrCreate('_deepLinkIntent', json); } catch (e) { console.warn('TiebaLite: AppStorage not ready, pendingDeepLink stored'); }
}

function parseQueryString(qs: string): string[] {
  const keys: string[] = [];
  const vals: string[] = [];
  const pairs: string[] = qs.split('&');
  for (const pair of pairs) {
    const idx: number = pair.indexOf('=');
    if (idx > 0) {
      keys.push(pair.substring(0, idx));
      vals.push(pair.substring(idx + 1));
    }
  }
  const result: string[] = [];
  const kc: number = keys.length;
  for (let i = 0; i < kc; i++) {
    result.push(keys[i] + '=' + vals[i]);
  }
  return result;
}

function lookupQuery(qsParts: string[], key: string): string {
  for (const part of qsParts) {
    const idx: number = part.indexOf('=');
    if (idx > 0 && part.substring(0, idx) === key) {
      return part.substring(idx + 1);
    }
  }
  return '';
}

function parseDeepLink(uri: string): void {
  if (!uri) return;
  try {
    if (uri.startsWith('tiebalite://')) {
      const path: string = uri.substring('tiebalite://'.length);
      const parts: string[] = path.split('/');
      if (parts.length >= 3 && parts[0] === 'open') {
        const type: string = parts[1];
        const raw: string = parts[2].split('?')[0];
        if (type === 'thread' && raw) { setDeepLink('thread', 'threadId', raw, '', ''); return; }
        if (type === 'forum' && raw) { setDeepLink('forum', 'forumName', decodeURIComponent(raw), '', ''); return; }
        if (type === 'user' && raw) { setDeepLink('userprofile', 'uid', raw, '', ''); return; }
        if (type === 'search') {
          const qi: number = uri.indexOf('?');
          const qs: string = qi >= 0 ? uri.substring(qi + 1) : '';
          const qParts: string[] = parseQueryString(qs);
          const kw: string = lookupQuery(qParts, 'keyword');
          if (kw) { setDeepLink('search', 'keyword', kw, '', ''); return; }
        }
      }
    }
    if (uri.startsWith('com.baidu.tieba://unidispatch')) {
      const path: string = uri.substring('com.baidu.tieba://unidispatch'.length);
      if (path.startsWith('/frs')) {
        const qi: number = path.indexOf('?');
        if (qi >= 0) {
          const qParts: string[] = parseQueryString(path.substring(qi + 1));
          const kw: string = lookupQuery(qParts, 'kw');
          if (kw) { setDeepLink('forum', 'forumName', decodeURIComponent(kw), '', ''); return; }
        }
      }
      if (path.startsWith('/pb')) {
        const qi: number = path.indexOf('?');
        if (qi >= 0) {
          const qParts: string[] = parseQueryString(path.substring(qi + 1));
          const tid: string = lookupQuery(qParts, 'tid');
          if (tid) { setDeepLink('thread', 'threadId', tid, '', ''); return; }
        }
      }
    }
    if (uri.startsWith('https://tieba.baidu.com') || uri.startsWith('http://tieba.baidu.com')) {
      const domain: string = 'tieba.baidu.com';
      const di: number = uri.indexOf(domain);
      const path: string = di >= 0 ? uri.substring(di + domain.length) : '';
      if (path.startsWith('/p/')) {
        const tid: string = path.substring(3).split('/')[0].split('?')[0];
        const qi: number = path.indexOf('?');
        if (qi >= 0) {
          const qParts: string[] = parseQueryString(path.substring(qi + 1));
          const pid: string = lookupQuery(qParts, 'pid');
          if (pid && tid) { setDeepLink('subposts', 'threadId', tid, 'postId', pid); return; }
        }
        if (tid) { setDeepLink('thread', 'threadId', tid, '', ''); return; }
      }
      if (path.startsWith('/f')) {
        const qi: number = path.indexOf('?');
        if (qi >= 0) {
          const qParts: string[] = parseQueryString(path.substring(qi + 1));
          const kw: string = lookupQuery(qParts, 'kw');
          if (kw) { setDeepLink('forum', 'forumName', decodeURIComponent(kw), '', ''); return; }
        }
      }
      if (path.startsWith('/home/')) {
        const qi: number = path.indexOf('?');
        if (qi >= 0) {
          const qParts: string[] = parseQueryString(path.substring(qi + 1));
          const uid: string = lookupQuery(qParts, 'id') || lookupQuery(qParts, 'uid');
          if (uid) { setDeepLink('userprofile', 'uid', uid, '', ''); return; }
        }
      }
      if (path.includes('/search')) {
        const qi: number = path.indexOf('?');
        if (qi >= 0) {
          const qParts: string[] = parseQueryString(path.substring(qi + 1));
          const kw: string = decodeURIComponent(lookupQuery(qParts, 'word') || lookupQuery(qParts, 'keyword') || lookupQuery(qParts, 'wd'));
          if (kw) { setDeepLink('search', 'keyword', kw, '', ''); return; }
        }
      }
    }
  } catch (e) {
    console.error('TiebaLite: parseDeepLink err ' + JSON.stringify(e) + ' uri=' + (uri || '').substring(0, 100));
  }
}

export default class EntryAbility extends Ability {

  private processWant(w: Record<string, Object>, source: string): void {
    let wantStr: string = '';
    try { wantStr = JSON.stringify(w).substring(0, 800); } catch (e) {}
    console.info('TiebaLite: deepLink ' + source + ' want=' + wantStr);
    // Log all top-level keys and types
    let allKeys: string = '';
    for (const k of Object.keys(w)) {
      const v: Object = w[k];
      const t: string = typeof v;
      let vs: string = '';
      if (typeof v === 'string') vs = (v as string).substring(0, 120);
      else if (v && typeof v === 'object') { try { vs = 'OBJ(' + Object.keys(v as Record<string, Object>).join(',') + ')'; } catch (_e) {} }
      else vs = String(v);
      allKeys += k + ':' + t + '=' + vs + ' | ';
    }
    console.info('TiebaLite: deepLink ' + source + ' keys=' + allKeys);
    const candidates: string[] = [];
    if (typeof w['uri'] === 'string') candidates.push(w['uri'] as string);
    if (typeof w['link'] === 'string') candidates.push(w['link'] as string);
    if (typeof w['data'] === 'string') candidates.push(w['data'] as string);
    if (typeof w['targetUri'] === 'string') candidates.push(w['targetUri'] as string);
    if (typeof w['url'] === 'string') candidates.push(w['url'] as string);
    if (w['parameters']) {
      const p: Record<string, string> = w['parameters'] as Record<string, string>;
      for (const pk of Object.keys(p)) {
        const pv: string = p[pk];
        if (typeof pv === 'string' && (pv.startsWith('http') || pv.startsWith('com.baidu') || pv.startsWith('tiebalite'))) candidates.push(pv);
      }
      console.info('TiebaLite: deepLink ' + source + ' paramKeys=' + Object.keys(p).join(','));
    }
    console.info('TiebaLite: deepLink ' + source + ' candidates=' + candidates.join(' | '));
    for (const c of candidates) {
      if (c) {
        parseDeepLink(c);
        break;
      }
    }
  }

  onCreate(want: object, launchParam: object): void {
    this.processWant(want as Record<string, Object> || {} as Record<string, Object>, 'onCreate');
    try {
      webview.WebviewController.initializeWebEngine();
      console.info('TiebaLite: [A0] webview engine initialized');
    } catch (e) {
      console.error('TiebaLite: [A0] webview engine init err: ' + JSON.stringify(e));
    }
  }

  async onWindowStageCreate(windowStage: Window.WindowStage): Promise<void> {
    console.info('TiebaLite: [A1] onWindowStageCreate start');
    const context = this.context;

    try { console.info('TiebaLite: [A2] PreferencesManager.init'); PreferencesManager.init(context); console.info('TiebaLite: [A2] done'); } catch (e) { console.error('TiebaLite: [A2] err: ' + JSON.stringify(e)); }

    try { console.info('TiebaLite: [A3] DatabaseManager.init'); await DatabaseManager.init(context); console.info('TiebaLite: [A3] done'); } catch (e) { console.error('TiebaLite: [A3] err: ' + JSON.stringify(e)); }

    try { console.info('TiebaLite: [A4] DeviceFingerprint.init'); await DeviceFingerprint.getInstance().init(); console.info('TiebaLite: [A4] done'); } catch (e) { console.error('TiebaLite: [A4] err: ' + JSON.stringify(e)); }

    try { console.info('TiebaLite: [A5] AccountManager.init'); await AccountManager.getInstance().init(); console.info('TiebaLite: [A5] done'); } catch (e) { console.error('TiebaLite: [A5] err: ' + JSON.stringify(e)); }

    try { console.info('TiebaLite: [A6] ThemeProvider.init'); await ThemeProvider.getInstance().init(); console.info('TiebaLite: [A6] done'); } catch (e) { console.error('TiebaLite: [A6] err: ' + JSON.stringify(e)); }

    try {
      console.info('TiebaLite: [A7] detect system dark mode');
      const cfg = context.config as Record<string, number>;
      const colorMode = cfg['colorMode'];
      if (colorMode !== undefined) {
        const isDark = colorMode === 0;
        ThemeProvider.getInstance().setSystemDark(isDark);
        AppStorage.SetOrCreate('isSystemDark', isDark);
        console.info('TiebaLite: system colorMode=' + colorMode + ' isDark=' + isDark);
      }
    } catch (e) {
      console.warn('TiebaLite: cannot detect system dark mode');
    }

    try { console.info('TiebaLite: [A9] MessagePollingService.start'); MessagePollingService.getInstance().startPolling(); console.info('TiebaLite: [A9] done'); } catch (e) { console.error('TiebaLite: [A9] err: ' + JSON.stringify(e)); }

    try { console.info('TiebaLite: [A10] GripDetector.init'); GripDetector.init(); console.info('TiebaLite: [A10] done'); } catch (e) { console.error('TiebaLite: [A10] err: ' + JSON.stringify(e)); }
    try { console.info('TiebaLite: [A11] restore grip_enabled pref'); const gripEnabled = await PreferencesManager.getInstance().getBoolean('grip_enabled', true); AppStorage.SetOrCreate<boolean>('gripEnabled', gripEnabled); console.info('TiebaLite: [A11] done gripEnabled=' + gripEnabled); } catch (e) { console.error('TiebaLite: [A11] err: ' + JSON.stringify(e)); }
    try {
      console.info('TiebaLite: [A12] restore fab_radius pref'); const fabRadius = await PreferencesManager.getInstance().getInt('fab_radius', 60); AppStorage.SetOrCreate<number>('fabRadius', fabRadius); console.info('TiebaLite: [A12] done fabRadius=' + fabRadius); } catch (e) { console.error('TiebaLite: [A12] err: ' + JSON.stringify(e)); }

    try {
      console.info('TiebaLite: [A13] reset video/pip leftovers');
      AppStorage.SetOrCreate('videoFullscreenActive', false);
      AppStorage.Delete('fullscreenPipCtrl');
      AppStorage.Delete('fullscreenPipUrl');
      AppStorage.Delete('fullscreenPipStartTime');
      const win = await windowStage.getMainWindow();
      await win.setPreferredOrientation(Window.Orientation.PORTRAIT);
      console.info('TiebaLite: [A13] done');
    } catch (e) { console.error('TiebaLite: [A13] err: ' + JSON.stringify(e)); }

    console.info('TiebaLite: [A11] loadContent');
    windowStage.loadContent('pages/Index', async (err) => {
      if (err && err.code !== 0) {
        console.error('TiebaLite: [A10] loadContent failed: ' + JSON.stringify(err));
      } else {
        console.info('TiebaLite: [A10] Succeeded');
        await this.setSystemBarColors();
      }
    });
  }

  onNewWant(want: object, launchParam: object): void {
    this.processWant(want as Record<string, Object> || {} as Record<string, Object>, 'onNewWant');
  }

  onDestroy(): void {
    MessagePollingService.getInstance().stopPolling();
    console.info('TiebaLite: onDestroy');
  }

  onForeground(): void {
    console.info('TiebaLite: onForeground');
    AppStorage.SetOrCreate('appInBackground', false);
    this.setSystemBarColors();
  }

  onBackground(): void {
    console.info('TiebaLite: onBackground');
    AppStorage.SetOrCreate('appInBackground', true);
  }

  onConfigurationUpdate(newConfig: object): void {
    try {
      const cfg = newConfig as Record<string, number>;
      const cm = cfg['colorMode'];
      if (cm !== undefined) {
        const isDark = cm === 0;
        ThemeProvider.getInstance().setSystemDark(isDark);
        AppStorage.SetOrCreate('isSystemDark', isDark);
        console.info('TiebaLite: system colorMode changed to ' + cm);
      }
    } catch (e) {
      console.warn('TiebaLite: onConfigurationUpdate error: ' + JSON.stringify(e));
    }
  }

  private async setSystemBarColors(): Promise<void> {
    try {
      const isDark = AppStorage.Get<boolean>('isDarkTheme') ?? false;
      const iconColor = isDark ? '#FFFFFF' : '#000000';
      const win = await Window.getLastWindow(this.context);
      win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: iconColor,
        navigationBarContentColor: iconColor
      });
      win.setWindowBackgroundColor(pageBg(isDark));
      try { win.setWindowSystemBarEnable(['status']); } catch (_) {}
    } catch (e) {
      console.warn('TiebaLite: setSystemBarColors error: ' + JSON.stringify(e));
    }
  }
}
