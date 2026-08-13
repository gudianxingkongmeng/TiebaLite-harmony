import http from '@ohos.net.http';
import { util } from '@kit.ArkTS';
import fs from '@ohos.file.fs';
import AccountManager from '../auth/AccountManager';
import DeviceFingerprint from '../device/DeviceFingerprint';
import MD5 from '../encryption/MD5';
import { APP_SECRET, PARAM, ClientVersion } from '../network/HttpConstants';

export interface UploadResult {
  raw: Record<string, Object>;
}

export interface ChunkOptions {
  chunkSize?: number;
  fileName?: string;
  mime?: string;
  groupId?: string;
  picWaterType?: string;
  forumName?: string;
  width?: string;
  height?: string;
  resourceId?: string;
}

const DEFAULT_CHUNK_SIZE = 512000;

function buildCommonFields(): Record<string, string> {
  const device = DeviceFingerprint.getInstance();
  const account = AccountManager.getInstance().getCurrentAccountSync();
  const f: Record<string, string> = {};
  f[PARAM.CUID] = device.getCuid();
  f[PARAM.CLIENT_VERSION] = ClientVersion.TIEBA_V12;
  f[PARAM.CUID_GALAXY2] = device.getCuidGalaxy2();
  f[PARAM.CLIENT_ID] = device.getClientId();
  f[PARAM.CLIENT_TYPE] = '2';
  f[PARAM.OS_VERSION] = device.getOsVersion();
  f[PARAM.MODEL] = device.getModel();
  f[PARAM.NET_TYPE] = device.getNetType();
  f[PARAM.PHONE_IMEI] = device.getImei();
  if (account) {
    f[PARAM.BDUSS] = account.bduss;
    f[PARAM.STOKEN] = account.sToken;
  }
  f[PARAM.TIMESTAMP] = String(Date.now());
  f['stErrorNums'] = '1';
  f['stMethod'] = '1';
  f['stMode'] = '1';
  f['stTimesNum'] = '1';
  f['stTime'] = String(Math.floor(Math.random() * 750) + 100);
  f['stSize'] = String(Math.floor((Math.random() * 8 + 0.4) * Number(f['stTime'])));
  return f;
}

async function signFields(fields: Record<string, string>): Promise<Record<string, string>> {
  const keys = Object.keys(fields).sort();
  let toSign = '';
  for (const k of keys) {
    toSign += k + '=' + fields[k];
  }
  toSign += APP_SECRET;
  const sign = await MD5.hash(toSign);
  const out: Record<string, string> = { ...fields };
  out[PARAM.SIGN] = sign;
  return out;
}

async function buildMultipartBody(fields: Record<string, string>, fileBuf: ArrayBuffer, fileName: string, mime: string, fileFieldName: string = 'chunk'): Promise<{ body: ArrayBuffer; boundary: string }> {
  const signed = await signFields(fields);
  const keys = Object.keys(signed).sort();
  const encoder = new util.TextEncoder();
  const boundary = '----Boundary' + Math.random().toString(36).substring(2, 15);
  const parts: Uint8Array[] = [];
  for (const k of keys) {
    parts.push(encoder.encodeInto('--' + boundary + '\r\nContent-Disposition: form-data; name="' + k + '"\r\n\r\n' + signed[k] + '\r\n'));
  }
  parts.push(encoder.encodeInto('--' + boundary + '\r\nContent-Disposition: form-data; name="' + fileFieldName + '"; filename="' + fileName + '"\r\nContent-Type: ' + mime + '\r\n\r\n'));
  parts.push(new Uint8Array(fileBuf));
  parts.push(encoder.encodeInto('\r\n--' + boundary + '--\r\n'));
  let totalLength = 0;
  for (let i = 0; i < parts.length; i++) {
    totalLength += parts[i].byteLength;
  }
  const body = new Uint8Array(totalLength);
  let offset = 0;
  for (let i = 0; i < parts.length; i++) {
    body.set(parts[i], offset);
    offset += parts[i].byteLength;
  }
  return { body: body.buffer as ArrayBuffer, boundary: boundary };
}

function parseResult(raw: Object): Record<string, Object> | null {
  if (raw === undefined || raw === null) return null;
  if (typeof raw === 'string') {
    try { return JSON.parse(raw as string) as Record<string, Object>; } catch (e) {
      console.error('TiebaLite: parseResult JSON fail=' + String(e));
      return null;
    }
  }
  return raw as Record<string, Object>;
}

function checkError(root: Record<string, Object> | null): string {
  if (!root) return 'no_response';
  const code = String(root['error_code'] ?? root['errno'] ?? root['no'] ?? '0');
  if (code !== '0' && code !== '300000') {
    return 'code_' + code + '_' + String(root['error_msg'] || root['msg'] || '');
  }
  return '';
}

async function postForm(url: string, fields: Record<string, string>): Promise<Record<string, Object> | null> {
  const signed = await signFields(fields);
  const keys = Object.keys(signed).sort();
  const parts: string[] = [];
  for (const k of keys) {
    parts.push(encodeURIComponent(k) + '=' + encodeURIComponent(signed[k]));
  }
  const bodyStr = parts.join('&');
  const account = AccountManager.getInstance().getCurrentAccountSync();
  const httpRequest = http.createHttp();
  try {
    const resp = await httpRequest.request(url, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': 'bdtb for Android ' + ClientVersion.TIEBA_V12,
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'zh-CN,en-US;q=0.9',
        'Connection': 'Keep-Alive',
        'Cookie': 'ka=open' + (account ? '; BDUSS=' + account.bduss : '')
      },
      extraData: bodyStr,
      expectDataType: http.HttpDataType.OBJECT
    });
    console.info('TiebaLite: postForm url=' + url.substring(url.lastIndexOf('/') + 1) + ' code=' + String(resp.responseCode));
    return parseResult(resp.result as Object);
  } catch (e) {
    console.error('TiebaLite: postForm error=' + String(e));
    return null;
  } finally {
    httpRequest.destroy();
  }
}

async function postMultipart(url: string, fields: Record<string, string>, fileBuf: ArrayBuffer, fileName: string, mime: string, fileFieldName: string): Promise<Record<string, Object> | null> {
  const built = await buildMultipartBody(fields, fileBuf, fileName, mime, fileFieldName);
  const account = AccountManager.getInstance().getCurrentAccountSync();
  const httpRequest = http.createHttp();
  try {
    const resp = await httpRequest.request(url, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'multipart/form-data; boundary=' + built.boundary,
        'Connection': 'Keep-Alive',
        'User-Agent': 'bdtb for Android ' + ClientVersion.TIEBA_V12,
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'zh-CN,en-US;q=0.9',
        'Cookie': 'ka=open' + (account ? '; BDUSS=' + account.bduss : '')
      },
      extraData: built.body,
      expectDataType: http.HttpDataType.OBJECT
    });
    console.info('TiebaLite: postMultipart url=' + url.substring(url.lastIndexOf('/') + 1) + ' code=' + String(resp.responseCode) + ' bytes=' + String(fileBuf.byteLength));
    return parseResult(resp.result as Object);
  } catch (e) {
    console.error('TiebaLite: postMultipart error=' + String(e));
    return null;
  } finally {
    httpRequest.destroy();
  }
}

export interface VideoUploadResult {
  videoMd5: string;
  videoUrl: string;
}

const VIDEO_CHUNK_SIZE = 524288;
const VIDEO_STATUS_URL = 'https://c.tieba.baidu.com/c/c/video/uploadVideoStatus';
const VIDEO_DATA_URL = 'https://c.tieba.baidu.com/c/c/video/uploadVideoData';

export async function uploadVideoToTieba(path: string, opts: { durationMs: number; onProgress?: (percent: number) => void }): Promise<VideoUploadResult | null> {
  try {
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    const stat = fs.statSync(path);
    const total = stat.size;
    if (total <= 0) {
      fs.closeSync(file);
      return null;
    }
    const buf = new ArrayBuffer(total);
    let got = 0;
    while (got < total) {
      const n = fs.readSync(file.fd, buf, { offset: got, length: total - got });
      if (n <= 0) break;
      got += n;
    }
    fs.closeSync(file);
    if (got !== total) {
      console.error('TiebaLite: video read incomplete got=' + String(got) + ' total=' + String(total));
      return null;
    }
    opts.onProgress?.(2);
    const md5 = await MD5.hashBytes(new Uint8Array(buf));
    const chunkSum = Math.max(1, Math.ceil(total / VIDEO_CHUNK_SIZE));
    const account = AccountManager.getInstance().getCurrentAccountSync();
    const common = buildCommonFields();
    const base: Record<string, string> = {
      chunk_sum: String(chunkSum),
      video_size: String(total),
      chunk_size: String(VIDEO_CHUNK_SIZE),
      video_md5: md5,
      video_len: String(opts.durationMs),
      tbs: account?.tbs || ''
    };
    console.info('TiebaLite: video upload start size=' + String(total) + ' md5=' + md5 + ' chunkSum=' + String(chunkSum) + ' lenMs=' + String(opts.durationMs));

    const st0 = await postForm(VIDEO_STATUS_URL, { ...common, ...base, is_merge: '0' });
    const err0 = checkError(st0);
    if (err0) {
      console.error('TiebaLite: video status0 failed ' + err0 + ' raw=' + JSON.stringify(st0).substring(0, 300));
      return null;
    }
    opts.onProgress?.(5);
    const data0 = st0?.['data'] as Record<string, Object> | undefined;
    const url0 = String(data0?.['video_url'] || '');
    if (url0) {
      console.info('TiebaLite: video instant success url=' + url0);
      return { videoMd5: md5, videoUrl: url0 };
    }
    const uploadId = String(data0?.['upload_id'] || '');
    const noList = data0?.['chunk_nolist'];
    const missing: number[] = [];
    if (Array.isArray(noList)) {
      for (const v of noList) {
        missing.push(Number(v));
      }
    }
    if (missing.length === 0) {
      for (let i = 1; i <= chunkSum; i++) missing.push(i);
    }
    console.info('TiebaLite: video status0 ok uploadId=' + uploadId + ' missing=' + JSON.stringify(missing));

    const fileName = path.substring(path.lastIndexOf('/') + 1) || 'video.mp4';
    let doneNo = 0;
    for (const no of missing) {
      const start = (no - 1) * VIDEO_CHUNK_SIZE;
      const end = Math.min(total, start + VIDEO_CHUNK_SIZE);
      const cur = buf.slice(start, end);
      const fields: Record<string, string> = { ...common, ...base, chunk_no: String(no), chunk_size: String(cur.byteLength), upload_id: uploadId };
      const r = await postMultipart(VIDEO_DATA_URL, fields, cur, fileName, 'video/mp4', 'video_chunk');
      const errChunk = checkError(r);
      if (errChunk) {
        console.error('TiebaLite: video chunk ' + no + ' failed ' + errChunk + ' raw=' + JSON.stringify(r).substring(0, 300));
        return null;
      }
      doneNo++;
      opts.onProgress?.(5 + (doneNo / missing.length) * 90);
      const d = r?.['data'] as Record<string, Object> | undefined;
      if (d?.['video_url']) {
        console.info('TiebaLite: video chunk ' + no + ' ok url=' + String(d['video_url']));
      } else {
        console.info('TiebaLite: video chunk ' + no + ' ok');
      }
    }

    const st1 = await postForm(VIDEO_STATUS_URL, { ...common, ...base, is_merge: '1', upload_id: uploadId });
    opts.onProgress?.(98);
    const err1 = checkError(st1);
    if (err1) {
      console.error('TiebaLite: video merge failed ' + err1 + ' raw=' + JSON.stringify(st1).substring(0, 300));
      return null;
    }
    const data1 = st1?.['data'] as Record<string, Object> | undefined;
    const url1 = String(data1?.['video_url'] || '');
    if (url1) {
      console.info('TiebaLite: video merge done url=' + url1);
      return { videoMd5: md5, videoUrl: url1 };
    }
    console.error('TiebaLite: video merge no url raw=' + JSON.stringify(st1).substring(0, 300));
    return null;
  } catch (e) {
    console.error('TiebaLite: uploadVideoToTieba error=' + String(e));
    return null;
  }
}

export { MD5, buildCommonFields, signFields };

export async function uploadChunked(url: string, fileBuf: ArrayBuffer, opts?: ChunkOptions): Promise<Record<string, Object> | null> {
  const chunkSize = opts?.chunkSize || DEFAULT_CHUNK_SIZE;
  const fileName = opts?.fileName || 'upload';
  const mime = opts?.mime || 'application/octet-stream';
  const total = fileBuf.byteLength;
  const chunkCount = Math.max(1, Math.ceil(total / chunkSize));
  const common = buildCommonFields();
  const account = AccountManager.getInstance().getCurrentAccountSync();

  let lastRaw: Record<string, Object> | null = null;
  for (let i = 0; i < chunkCount; i++) {
    const start = i * chunkSize;
    const end = Math.min(total, start + chunkSize);
    const cur = fileBuf.slice(start, end);
    const isFinish = i === chunkCount - 1 ? '1' : '0';
    const fields: Record<string, string> = { ...common };
    fields['alt'] = 'json';
    fields['chunkNo'] = String(i + 1);
    fields['isFinish'] = isFinish;
    fields['is_bjh'] = '0';
    fields['saveOrigin'] = '1';
    fields['size'] = String(total);
    fields['width'] = opts?.width || '0';
    fields['height'] = opts?.height || '0';
    if (opts?.groupId !== undefined) fields['groupId'] = opts.groupId;
    if (opts?.picWaterType !== undefined) fields['pic_water_type'] = opts.picWaterType;
    if (opts?.forumName) {
      fields['forum_name'] = opts.forumName;
      fields['small_flow_fname'] = opts.forumName;
    }
    if (opts?.resourceId) fields['resourceId'] = opts.resourceId;

    const built = await buildMultipartBody(fields, cur, fileName, mime);
    const httpRequest = http.createHttp();
    try {
      const resp = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'multipart/form-data; boundary=' + built.boundary,
          'Connection': 'Keep-Alive',
          'User-Agent': 'bdtb for Android ' + ClientVersion.TIEBA_V12,
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'zh-CN,en-US;q=0.9',
          'Cookie': 'ka=open' + (account ? '; BDUSS=' + account.bduss : '')
        },
        extraData: built.body,
        expectDataType: http.HttpDataType.STRING
      });
      console.info('TiebaLite: uploadChunked chunk ' + (i + 1) + '/' + String(chunkCount) + ' code=' + String(resp.responseCode) + ' type=' + typeof resp.result);
      const raw = resp.result as Object;
      if (raw === undefined || raw === null) {
        console.error('TiebaLite: uploadChunked chunk ' + (i + 1) + ' result is empty, header=' + JSON.stringify(resp.header).substring(0, 300));
        lastRaw = null;
      } else if (typeof raw === 'string') {
        console.info('TiebaLite: uploadChunked chunk ' + (i + 1) + ' respStr=' + (raw as string).substring(0, 300));
        try { lastRaw = JSON.parse(raw as string) as Record<string, Object>; } catch (e) { console.error('TiebaLite: uploadChunked chunk ' + (i + 1) + ' parse fail'); lastRaw = null; }
      } else {
        console.info('TiebaLite: uploadChunked chunk ' + (i + 1) + ' respObj=' + JSON.stringify(raw).substring(0, 300));
        lastRaw = raw as Record<string, Object>;
      }
    } catch (e) {
      console.error('TiebaLite: uploadChunked chunk ' + (i + 1) + ' error=' + String(e));
      return null;
    } finally {
      httpRequest.destroy();
    }
  }
  return lastRaw;
}
