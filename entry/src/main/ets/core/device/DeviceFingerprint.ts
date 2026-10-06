import { Dict } from '../types/Dict';
import deviceInfo from '@ohos.deviceInfo';
import UIDGenerator from './UIDGenerator';
import PreferencesManager from '../storage/PreferencesManager';

export default class DeviceFingerprint {
  private static instance: DeviceFingerprint;
  private _cuid: string = '';
  private _cuidGalaxy2: string = '';
  private _cuidGalaxy3: string = '';
  private _cuidGid: string = '';
  private _clientId: string = '';
  private _imei: string = '';
  private _oaid: string = '';
  private _androidId: string = '';
  private _zid: string = '';
  private _model: string = '';
  private _brand: string = '';
  private _screenWidth: number = 1080;
  private _screenHeight: number = 1920;
  private _screenDensity: number = 2.75;
  private _netType: string = '1';

  private constructor() {}

  static getInstance(): DeviceFingerprint {
    if (!DeviceFingerprint.instance) {
      DeviceFingerprint.instance = new DeviceFingerprint();
    }
    return DeviceFingerprint.instance;
  }

  async init(): Promise<void> {
    this._model = (deviceInfo as Dict).model as string || '';
    this._brand = (deviceInfo as Dict).brand as string || '';

    const prefs = PreferencesManager.getInstance();

    let androidId = await prefs.getString('android_id', '');
    if (!androidId) {
      androidId = await UIDGenerator.generateAndroidId();
      await prefs.putString('android_id', androidId);
    }
    this._androidId = androidId;

    let cuid = await prefs.getString('cuid', '');
    if (!cuid) {
      cuid = await UIDGenerator.generateCuid(androidId);
      await prefs.putString('cuid', cuid);
    }
    this._cuid = cuid;

    let cg2 = await prefs.getString('cuid_galaxy2', '');
    if (!cg2) {
      cg2 = await UIDGenerator.generateCuidGalaxy2(androidId);
      await prefs.putString('cuid_galaxy2', cg2);
    }
    this._cuidGalaxy2 = cg2;

    let cg3 = await prefs.getString('cuid_galaxy3', '');
    if (!cg3) {
      cg3 = UIDGenerator.generateHexString(32);
      await prefs.putString('cuid_galaxy3', cg3);
    }
    this._cuidGalaxy3 = cg3;

    this._cuidGid = '';

    let clientId = await prefs.getString('client_id', '');
    if (!clientId) {
      clientId = UIDGenerator.generateClientId();
      await prefs.putString('client_id', clientId);
    }
    this._clientId = clientId;

    this._imei = UIDGenerator.generateImei();

    this._oaid = JSON.stringify({
      oaid: UIDGenerator.generateHexString(16),
      status: 0,
      support: true,
      trackLimited: false
    });

    this._zid = await prefs.getString('zid', '');
  }

  getCuid(): string { return this._cuid; }
  getCuidGalaxy2(): string { return this._cuidGalaxy2; }
  getCuidGalaxy3(): string { return this._cuidGalaxy3; }
  getCuidGid(): string { return this._cuidGid; }
  getClientId(): string { return this._clientId; }
  getImei(): string { return this._imei; }
  getOaidJson(): string { return this._oaid; }
  getAndroidId(): string { return this._androidId; }
  getModel(): string { return this._model; }
  getBrand(): string { return this._brand; }
  getOsVersion(): string { return deviceInfo.sdkApiVersion.toString(); }
  getNetType(): string { return this._netType; }
  getScreenWidth(): number { return this._screenWidth; }
  getScreenHeight(): number { return this._screenHeight; }
  getScreenDensity(): number { return this._screenDensity; }
  getZid(): string { return this._zid; }
  getFirstInstallTime(): string { return String(Math.floor(Date.now() / 1000) - 86400 * 30); }
  getLastUpdateTime(): string { return String(Math.floor(Date.now() / 1000) - 86400); }
  getSampleId(): string { return UIDGenerator.generateSampleId(); }
  getBaiduId(): string { return UIDGenerator.generateBaiduId(); }

  setZid(zid: string): void {
    this._zid = zid;
    PreferencesManager.getInstance().putString('zid', zid);
  }

  setNetType(type: string): void {
    this._netType = type;
  }

  setScreenSize(w: number, h: number, d: number): void {
    this._screenWidth = w;
    this._screenHeight = h;
    this._screenDensity = d;
  }
}
