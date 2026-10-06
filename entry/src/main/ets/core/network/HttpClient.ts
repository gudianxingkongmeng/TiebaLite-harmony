import axios, { AxiosInstance, AxiosResponse, AxiosError, InternalAxiosRequestConfig, AxiosRequestHeaders } from '@ohos/axios';
import http from '@ohos.net.http';
import { util } from '@kit.ArkTS';
import { API_BASE_URLS, APP_SECRET, HEADER, PARAM, ERROR_CODES, ClientVersion } from './HttpConstants';
import AccountManager from '../auth/AccountManager';
import DeviceFingerprint from '../device/DeviceFingerprint';
import MD5 from '../encryption/MD5';
import { ungzip } from '../../lib/pako_arkts';

interface Interceptor {
  process(config: InternalAxiosRequestConfig): InternalAxiosRequestConfig;
}

export class CommonHeaderInterceptor implements Interceptor {
  process(config: InternalAxiosRequestConfig): InternalAxiosRequestConfig {
    if (!config.headers) config.headers = {} as AxiosRequestHeaders;
    config.headers[HEADER.ACCEPT] = 'application/json, text/plain, */*';
    config.headers[HEADER.ACCEPT_LANGUAGE] = 'zh-CN,en-US;q=0.9';
    config.headers[HEADER.USER_AGENT] = 'Mozilla/5.0 (Linux; Android 14; HarmonyOS) AppleWebKit/537.36 bdtb/12.52.1.0';
    config.headers['Connection'] = 'Keep-Alive';
    config.headers[HEADER.PRAGMA] = 'no-cache';
    return config;
  }
}

export class CommonParamInterceptor implements Interceptor {
  private device: DeviceFingerprint;
  private accountManager: AccountManager;

  constructor() {
    this.device = DeviceFingerprint.getInstance();
    this.accountManager = AccountManager.getInstance();
  }

  process(config: InternalAxiosRequestConfig): InternalAxiosRequestConfig {
    if (config.headers?.[HEADER.NO_COMMON_PARAMS]) return config;

    const params: Record<string, string> = {};

    params[PARAM.CUID] = this.device.getCuid();
    params[PARAM.CLIENT_ID] = this.device.getClientId();
    params[PARAM.CLIENT_TYPE] = '2';
    params[PARAM.OS_VERSION] = this.device.getOsVersion();
    params[PARAM.MODEL] = this.device.getModel();
    params[PARAM.NET_TYPE] = this.device.getNetType();
    params[PARAM.PHONE_IMEI] = this.device.getImei();

    const account = this.accountManager.getCurrentAccountSync();
    if (account) {
      params[PARAM.BDUSS] = account.bduss;
      params[PARAM.STOKEN] = account.sToken;
      params[PARAM.TBS] = account.tbs;
    }

    config.params = { ...config.params, ...params };
    config.headers = config.headers || {} as AxiosRequestHeaders;
    config.headers['Cookie'] = 'ka=open';

    return config;
  }
}

export class SortAndSignInterceptor implements Interceptor {
  process(config: InternalAxiosRequestConfig): InternalAxiosRequestConfig {
    const params = { ...config.params } as Record<string, string>;

    if (!params[PARAM.CLIENT_VERSION]) {
      params[PARAM.CLIENT_VERSION] = ClientVersion.TIEBA_V12;
    }

    params[PARAM.TIMESTAMP] = String(Date.now());

    config.params = params;
    return config;
  }
}

export class StParamInterceptor implements Interceptor {
  process(config: InternalAxiosRequestConfig): InternalAxiosRequestConfig {
    if (config.headers?.[HEADER.NO_ST_PARAMS]) return config;

    const stTime = Math.floor(Math.random() * 750) + 100;
    const stSize = Math.floor((Math.random() * 8 + 0.4) * stTime);

    config.params = {
      ...config.params,
      stErrorNums: Math.random() < 0.05 ? '0' : '1',
      stMethod: Math.random() < 0.5 ? '1' : '2',
      stMode: '1',
      stTimesNum: '1',
      stTime: String(stTime),
      stSize: String(stSize)
    };

    return config;
  }
}

export class HttpClient {
  private static instance: HttpClient;
  private clients: Map<string, AxiosInstance> = new Map();
  private interceptors: Interceptor[] = [];

  private constructor() {
    this.interceptors.push(new CommonHeaderInterceptor());
    this.interceptors.push(new CommonParamInterceptor());
    this.interceptors.push(new StParamInterceptor());
    this.interceptors.push(new SortAndSignInterceptor());
  }

  static getInstance(): HttpClient {
    if (!HttpClient.instance) {
      HttpClient.instance = new HttpClient();
    }
    return HttpClient.instance;
  }

  private getClient(baseURL: string): AxiosInstance {
    if (!this.clients.has(baseURL)) {
      const client = axios.create({
        baseURL: baseURL,
        timeout: 30000,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json'
        }
      });

      client.interceptors.request.use((config: InternalAxiosRequestConfig) => {
        for (const interceptor of this.interceptors) {
          config = interceptor.process(config);
        }
        return config;
      });

      client.interceptors.response.use(
        (response: AxiosResponse) => response,
        (error: AxiosError) => {
          return Promise.reject(error);
        }
      );

      this.clients.set(baseURL, client);
    }
    return this.clients.get(baseURL)!;
  }

  async get<T>(baseURL: string, path: string, params?: Record<string, string>, headers?: Record<string, string>): Promise<AxiosResponse<T>> {
    const client = this.getClient(baseURL);
    return client.get(path, { params, headers });
  }

  async simpleGet<T>(baseURL: string, path: string, params?: Record<string, string>, extraHeaders?: Record<string, string>): Promise<AxiosResponse<T>> {
    const device = DeviceFingerprint.getInstance();
    const account = AccountManager.getInstance().getCurrentAccountSync();
    const allParams: Record<string, string> = { ...params };
    if (!allParams[PARAM.CUID]) allParams[PARAM.CUID] = device.getCuid();
    if (!allParams[PARAM.CLIENT_VERSION]) allParams[PARAM.CLIENT_VERSION] = ClientVersion.TIEBA_V12;
    if (!allParams[PARAM.CLIENT_TYPE]) allParams[PARAM.CLIENT_TYPE] = '2';
    if (!allParams[PARAM.OS_VERSION]) allParams[PARAM.OS_VERSION] = device.getOsVersion();
    if (!allParams[PARAM.MODEL]) allParams[PARAM.MODEL] = device.getModel();
    if (!allParams[PARAM.NET_TYPE]) allParams[PARAM.NET_TYPE] = device.getNetType();
    if (!allParams[PARAM.PHONE_IMEI]) allParams[PARAM.PHONE_IMEI] = device.getImei();
    if (account) {
      if (!allParams[PARAM.BDUSS]) allParams[PARAM.BDUSS] = account.bduss;
      if (!allParams[PARAM.STOKEN]) allParams[PARAM.STOKEN] = account.sToken;
    }
    const qs = '?' + Object.entries(allParams).map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`).join('&');
    const url = baseURL.replace(/\/$/, '') + path + qs;
    const httpRequest = http.createHttp();
    return new Promise<AxiosResponse<T>>((resolve, reject) => {
      httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14; HarmonyOS) AppleWebKit/537.36',
          'Cookie': 'ka=open',
          ...(extraHeaders || {})
        },
        expectDataType: http.HttpDataType.OBJECT
      }).then((resp) => {
        httpRequest.destroy();
        const raw = resp.result as Object;
        let respData: Object;
        if (typeof raw === 'string') {
          try { respData = JSON.parse(raw as string); } catch (e) {
            console.error('TiebaLite: simpleGet JSON parse error=' + String(e));
            respData = {};
          }
        } else {
          respData = raw;
        }
        resolve({ data: respData, status: resp.responseCode, statusText: '' } as AxiosResponse<T>);
      }).catch((err) => {
        httpRequest.destroy();
        reject(new Error(String(err)));
      });
    });
  }

  async post<T>(baseURL: string, path: string, params?: Record<string, string>, extraHeaders?: Record<string, string>): Promise<AxiosResponse<T>> {
    const device = DeviceFingerprint.getInstance();
    const account = AccountManager.getInstance().getCurrentAccountSync();

    const formData: Record<string, string> = { ...params };

    if (!formData[PARAM.CUID]) formData[PARAM.CUID] = device.getCuid();
    if (!formData[PARAM.CLIENT_VERSION]) formData[PARAM.CLIENT_VERSION] = ClientVersion.TIEBA_V12;
    if (!formData[PARAM.CUID_GALAXY2]) formData[PARAM.CUID_GALAXY2] = device.getCuidGalaxy2();
    if (!formData[PARAM.CLIENT_ID]) formData[PARAM.CLIENT_ID] = device.getClientId();
    if (!formData[PARAM.CLIENT_TYPE]) formData[PARAM.CLIENT_TYPE] = '2';
    if (!formData[PARAM.OS_VERSION]) formData[PARAM.OS_VERSION] = device.getOsVersion();
    if (!formData[PARAM.MODEL]) formData[PARAM.MODEL] = device.getModel();
    if (!formData[PARAM.NET_TYPE]) formData[PARAM.NET_TYPE] = device.getNetType();
    if (!formData[PARAM.PHONE_IMEI]) formData[PARAM.PHONE_IMEI] = device.getImei();

    if (account) {
      formData[PARAM.BDUSS] = account.bduss;
      formData[PARAM.STOKEN] = account.sToken;
      if (!(PARAM.TBS in formData)) formData[PARAM.TBS] = account.tbs;
    }

    formData[PARAM.TIMESTAMP] = String(Date.now());

    if (!formData['stErrorNums']) formData['stErrorNums'] = '1';
    if (!formData['stMethod']) formData['stMethod'] = '1';
    if (!formData['stMode']) formData['stMode'] = '1';
    if (!formData['stTimesNum']) formData['stTimesNum'] = '1';
    if (!formData['stTime']) formData['stTime'] = String(Math.floor(Math.random() * 750) + 100);
    if (!formData['stSize']) formData['stSize'] = String(Math.floor((Math.random() * 8 + 0.4) * Number(formData['stTime'])));

    const keys = Object.keys(formData).sort();
    let toSign = '';
    const parts: string[] = [];
    for (const key of keys) {
      const val = formData[key];
      toSign += `${key}=${val}`;
      parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(val)}`);
    }
    toSign += APP_SECRET;
    console.info('TiebaLite: DEBUG toSign=' + toSign);
    const sign = await MD5.hash(toSign);
    console.info('TiebaLite: DEBUG sign=' + sign);
    parts.push(`${encodeURIComponent(PARAM.SIGN)}=${encodeURIComponent(sign)}`);

    const bodyStr = parts.join('&');
    const url = baseURL.replace(/\/$/, '') + path;

    console.info('TiebaLite: POST url=' + url);
    console.info('TiebaLite: POST body=' + bodyStr);

    const httpHeaders: Record<string, string> = {
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': 'bdtb for Android ' + (formData[PARAM.CLIENT_VERSION] || ClientVersion.TIEBA_V12),
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'zh-CN,en-US;q=0.9',
      'Cookie': 'ka=open',
      'Connection': 'Keep-Alive',
      ...(extraHeaders || {})
    };
    if (account) {
      httpHeaders['client_user_token'] = String(account.uid || 0);
    }

    const httpRequest = http.createHttp();
    return new Promise<AxiosResponse<T>>((resolve, reject) => {
      httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: httpHeaders,
        extraData: bodyStr,
        expectDataType: http.HttpDataType.OBJECT
      }).then((resp) => {
        httpRequest.destroy();
        const raw = resp.result as Object;
        let respData: Object;
        if (typeof raw === 'string') {
          try { respData = JSON.parse(raw as string); } catch (e) { respData = raw; }
        } else {
          respData = raw;
        }
        console.info('TiebaLite: POST response code=' + resp.responseCode + ' body=' + JSON.stringify(respData));
        resolve({ data: respData, status: resp.responseCode, statusText: '' } as AxiosResponse<T>);
      }).catch((err) => {
        httpRequest.destroy();
        console.error('TiebaLite: POST error=' + String(err));
        reject(new Error(String(err)));
      });
    });
  }

  async postUserLikeProtobuf(path: string, protobufData: Uint8Array, cmd: number): Promise<Uint8Array> {
    const device = DeviceFingerprint.getInstance();
    const url = API_BASE_URLS.PROTOBUF_TIEBA.replace(/\/$/, '') + path + '?cmd=' + cmd;
    const boundary: string = '-*_r1999';
    const encoder = new util.TextEncoder();
    const parts: Uint8Array[] = [];
    parts.push(encoder.encodeInto('--' + boundary + '\r\n'));
    parts.push(encoder.encodeInto('Content-Disposition: form-data; name="data"; filename="file"\r\n'));
    parts.push(encoder.encodeInto('\r\n'));
    parts.push(protobufData);
    parts.push(encoder.encodeInto('\r\n--' + boundary + '--\r\n'));
    let totalLength: number = 0;
    for (let i = 0; i < parts.length; i++) { totalLength += parts[i].length; }
    const body = new Uint8Array(totalLength);
    let offset: number = 0;
    for (let i = 0; i < parts.length; i++) { body.set(parts[i], offset); offset += parts[i].length; }
    const cuid: string = device.getCuid();
    let cookie: string = 'ka=open';
    if (cuid.length > 0) { cookie += ';CUID=' + cuid; }
    const headers: Record<string, string> = {
      'Content-Type': 'multipart/form-data; boundary=' + boundary,
      'User-Agent': 'bdtb for Android 12.64.1.1',
      [HEADER.X_BD_DATA_TYPE]: 'protobuf',
      'Accept-Encoding': 'gzip',
      'Cookie': cookie
    };
    if (cuid.length > 0) { headers['cuid'] = cuid; }
    const tempClient = axios.create({ responseType: 'array_buffer' });
    console.info('TiebaLite: postUserLikeProtobuf calling url=' + url);
    const response = await tempClient.post(url, body.buffer as ArrayBuffer, { headers: headers });
    const statusCode: number = (response as any).responseCode || (response as any).status || 0;
    console.info('TiebaLite: postUserLikeProtobuf status=' + statusCode + ' dataType=' + typeof response.data);
    if (statusCode !== 0 && statusCode !== 200) {
      throw new Error('protobuf POST returned status ' + statusCode);
    }
    const rawBytes = new Uint8Array(response.data as ArrayBuffer);
    console.info('TiebaLite: postUserLikeProtobuf rawBytesLen=' + rawBytes.length +
      ' firstBytes=' + (rawBytes.length >= 2 ? rawBytes[0].toString(16) + ',' + rawBytes[1].toString(16) : 'none'));
    if (rawBytes.length >= 2 && rawBytes[0] === 0x1f && rawBytes[1] === 0x8b) {
      console.info('TiebaLite: postUserLikeProtobuf detected gzip, decompressing...');
      try {
        const decompressed = ungzip(rawBytes);
        console.info('TiebaLite: postUserLikeProtobuf decompressed len=' + decompressed.length);
        return decompressed;
      } catch (e) {
        throw new Error('gzip decompress failed: ' + String(e));
      }
    }
    return rawBytes;
  }
}
