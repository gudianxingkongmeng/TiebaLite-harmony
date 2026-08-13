import pasteboard from '@ohos.pasteboard';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';

export interface ClipLink {
  type: string;
  url: string;
  threadId: number;
  forumName: string;
}

let lastClipHash: number = 0;

export function clipTextHash(text: string): number {
  let h: number = 0;
  for (let i = 0; i < text.length; i++) {
    h = ((h * 31 + text.charCodeAt(i)) >>> 0) % 2147483647;
  }
  return h;
}

export function isSameClipText(text: string): boolean {
  return lastClipHash > 0 && lastClipHash === clipTextHash(text);
}

export function rememberClipText(text: string): void {
  lastClipHash = clipTextHash(text);
}

function parseQuery(query: string): Record<string, string> {
  const out: Record<string, string> = {};
  const parts = query.split('&');
  for (const p of parts) {
    const idx = p.indexOf('=');
    if (idx <= 0) continue;
    const k = p.substring(0, idx);
    const v = decodeURIComponent(p.substring(idx + 1).replace(/\+/g, ' '));
    if (k) out[k] = v;
  }
  return out;
}

/**
 * 解析剪贴板文本中的贴吧链接（对齐 Android ClipBoardLinkDetector.parseLink）
 * 支持：https://tieba.baidu.com/f?kw=吧名、/mo/q/m?kw=吧名（吧）
 *       https://tieba.baidu.com/f?kz=123、/mo/q/m?kz=123、/p/123（帖）
 */
export function parseTiebaLink(text: string): ClipLink | null {
  const m = /((http|https):\/\/)([a-zA-Z0-9._-]+\.[a-zA-Z]{2,6}|(\d{1,3}\.){3}\d{1,3})(:\d{1,4})*(\/[a-zA-Z0-9&%_./\-~-]*)?/.exec(text);
  if (!m) return null;
  const url: string = m[0];
  const hs: number = url.indexOf('://') + 3;
  let pathStart: number = url.indexOf('/', hs);
  if (pathStart < 0) pathStart = url.length;
  const host: string = url.substring(hs, pathStart).toLowerCase();
  if (host !== 'tieba.baidu.com' && host !== 'tiebac.baidu.com' && host !== 'wapp.baidu.com') {
    return null;
  }
  const qIdx: number = url.indexOf('?');
  const path: string = qIdx < 0 ? url.substring(pathStart) : url.substring(pathStart, qIdx);
  const query: Record<string, string> = qIdx < 0 ? {} : parseQuery(url.substring(qIdx + 1));
  if (query['tbjump'] !== undefined) return null;

  const isF: boolean = path === '/f' || path === '/mo/q/m';
  if (isF) {
    const forumName: string = query['kw'] || query['word'] || '';
    if (forumName.length > 0) {
      return { type: 'forum', url: url, threadId: 0, forumName: forumName };
    }
    const kz: string = query['kz'] || '';
    if (kz && /^\d+$/.test(kz)) {
      return { type: 'thread', url: url, threadId: Number(kz), forumName: '' };
    }
  } else if (path.startsWith('/p/')) {
    let end: number = path.length;
    const amp: number = path.indexOf('&');
    if (amp >= 0) end = amp;
    const tidStr: string = path.substring(3, end);
    if (/^\d+$/.test(tidStr)) {
      const tid: number = Number(tidStr);
      if (tid > 0) return { type: 'thread', url: url, threadId: tid, forumName: '' };
    }
  }
  return null;
}

/** 读取剪贴板文本（含 READ_PASTEBOARD 运行时权限申请），无内容返回空串 */
export async function readClipBoardText(context: common.UIAbilityContext): Promise<string> {
  const atManager = abilityAccessCtrl.createAtManager();
  const status = await atManager.checkAccessToken(context.applicationInfo.accessTokenId, 'ohos.permission.READ_PASTEBOARD');
  if (status !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
    const result = await atManager.requestPermissionsFromUser(context, ['ohos.permission.READ_PASTEBOARD']);
    const granted = result.authResults && result.authResults.length > 0 && result.authResults[0] === 0;
    if (!granted) return '';
  }
  const sysBoard = pasteboard.getSystemPasteboard();
  const data = await sysBoard.getData();
  return data.getPrimaryText() || '';
}
