import { Dict } from '../types/Dict';
import { TiebaApi } from '../api/TiebaApi';
import ITiebaApi from '../api/ITiebaApi';
import FileCache from '../storage/FileCache';
import { common } from '@kit.AbilityKit';
import { HttpClient } from '../network/HttpClient';
import { encodeUserLikeReq, decodeUserLikeRes, IUserLikeReqParams } from '../../proto/UserLikeProto';
import AccountManager, { Account } from '../auth/AccountManager';
import DeviceFingerprint from '../device/DeviceFingerprint';

export default class ExploreRepository {
  private static instance: ExploreRepository;
  private api: ITiebaApi;
  private cache: FileCache;
  private http: HttpClient;

  private constructor(context?: common.Context) {
    this.api = TiebaApi.getInstance();
    this.http = HttpClient.getInstance();
    this.cache = context ? new FileCache(context) : null!;
  }

  static getInstance(): ExploreRepository {
    if (!ExploreRepository.instance) {
      ExploreRepository.instance = new ExploreRepository();
    }
    return ExploreRepository.instance;
  }

  async loadHotThreads(tabCode: string): Promise<Dict> {
    return new Promise<Dict>((resolve, reject) => {
      this.api.hotThreadList(tabCode, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async loadPersonalized(page: number): Promise<Dict> {
    return new Promise<Dict>((resolve, reject) => {
      this.api.personalized(1, page, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async loadPersonalizedProto(page: number): Promise<Dict> {
    return new Promise<Dict>((resolve, reject) => {
      this.api.personalizedProto(1, page, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }

  async loadUserLike(pageTag: string, loadType: string, lastRequestUnix: string, followType?: string): Promise<Dict> {
    return new Promise((resolve, reject) => {
      this.api.userLike(pageTag, loadType, lastRequestUnix, {
        onSuccess: (data) => resolve(data),
        onError: (code, msg) => reject({ code, msg })
      }, followType);
    });
  }

  async loadUserLikeFlow(pageTag: string, loadType: number): Promise<Dict> {
    const account: Account | null = AccountManager.getInstance().getCurrentAccountSync();
    const device = DeviceFingerprint.getInstance();
    const reqParams: IUserLikeReqParams = {
      pageTag: pageTag,
      lastRequestUnix: 0,
      loadType: loadType,
      bduss: account?.bduss || '',
      cuid: device.getCuid(),
      timestamp: Date.now(),
      netType: 1,
      stoken: account?.sToken || ''
    };
    const protobufBytes: Uint8Array = encodeUserLikeReq(reqParams);
    const responseBytes: Uint8Array = await this.http.postUserLikeProtobuf('/c/f/concern/userlike', protobufBytes, 309474);
    const result: Dict = decodeUserLikeRes(responseBytes);
    return result;
  }

  async submitDislike(dislikeData: Dict): Promise<void> {
    return new Promise((resolve, reject) => {
      this.api.submitDislike(JSON.stringify(dislikeData), {
        onSuccess: () => resolve(),
        onError: (code, msg) => reject({ code, msg })
      });
    });
  }
}
