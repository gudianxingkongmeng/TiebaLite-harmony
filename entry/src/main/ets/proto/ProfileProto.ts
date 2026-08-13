import { UserProfileInfo } from '../model/UserProfileModels';
import { ProtoWriter, ProtoReader } from './ProtoWire';

const PROFILE_VERSION: string = '12.41.7.1';

export interface IProfileReqParams {
  uid: number;
  portrait: string;
}

function encodeCommonReq(writer: ProtoWriter): void {
  writer.writeInt32(1, 2);
  writer.writeString(2, PROFILE_VERSION);
}

function encodeDataReq(params: IProfileReqParams): Uint8Array {
  const writer = new ProtoWriter();
  writer.writeInt32(2, 1);
  writer.writeInt32(15, 1);
  const commonWriter = new ProtoWriter();
  encodeCommonReq(commonWriter);
  writer.writeMessage(9, commonWriter.finish());
  if (params.uid > 0) {
    writer.writeInt32(1, params.uid);
  } else if (params.portrait.length > 0) {
    writer.writeString(16, params.portrait);
  }
  return writer.finish();
}

export function encodeProfileReq(params: IProfileReqParams): Uint8Array {
  const writer = new ProtoWriter();
  const dataBytes = encodeDataReq(params);
  writer.writeMessage(1, dataBytes);
  return writer.finish();
}

function decodeProfileUser(reader: ProtoReader): UserProfileInfo {
  const profile = new UserProfileInfo();
  let tshowIconCount: number = 0;
  while (!reader.isEnd()) {
    const tag = reader.readTag();
    switch (tag.fieldNumber) {
      case 2: profile.uid = reader.readVarint(); break;
      case 3: profile.userName = reader.readString(); break;
      case 4: profile.nickName = reader.readString(); break;
      case 5: {
        const rawPortrait: string = reader.readString();
        const qIndex: number = rawPortrait.indexOf('?');
        profile.portrait = qIndex >= 0 ? rawPortrait.substring(0, qIndex) : rawPortrait;
        break;
      }
      case 30: profile.fanNum = reader.readVarint(); break;
      case 31: profile.followNum = reader.readVarint(); break;
      case 32: profile.gender = reader.readVarint(); break;
      case 34: profile.sign = reader.readString(); break;
      case 35: profile.isFollowing = reader.readVarint() !== 0; break;
      case 37: profile.postNum = reader.readVarint(); break;
      case 87: profile.threadNum = reader.readVarint(); break;
      case 38: {
        const ageStr: string = reader.readString();
        const parsed: number = parseFloat(ageStr);
        profile.age = Number.isNaN(parsed) ? 0 : parsed;
        break;
      }
      case 65: reader.readMessage(); tshowIconCount++; break;
      case 120: {
        const tiebaUidStr: string = reader.readString();
        const parsedUid: number = parseInt(tiebaUidStr, 10);
        profile.tiebaUid = Number.isNaN(parsedUid) ? 0 : parsedUid;
        break;
      }
      default: reader.skipField(tag.wireType); break;
    }
  }
  profile.isVip = tshowIconCount > 0;
  return profile;
}

function decodeUserAgreeInfo(reader: ProtoReader): number {
  let totalAgreeNum: number = 0;
  while (!reader.isEnd()) {
    const tag = reader.readTag();
    if (tag.fieldNumber === 1) {
      totalAgreeNum = reader.readVarint();
    } else {
      reader.skipField(tag.wireType);
    }
  }
  return totalAgreeNum;
}

export function decodeProfileRes(bytes: Uint8Array): UserProfileInfo {
  const reader = new ProtoReader(bytes);
  let profile: UserProfileInfo = new UserProfileInfo();
  let agreeNum: number = 0;
  while (!reader.isEnd()) {
    const tag = reader.readTag();
    if (tag.fieldNumber === 1) {
      const errReader = reader.readMessage();
      let errorNo: number = 0;
      let errorMsg: string = '';
      while (!errReader.isEnd()) {
        const errTag = errReader.readTag();
        if (errTag.fieldNumber === 1) {
          errorNo = errReader.readVarint();
        } else if (errTag.fieldNumber === 2) {
          errorMsg = errReader.readString();
        } else {
          errReader.skipField(errTag.wireType);
        }
      }
      if (errorNo !== 0) {
        throw new Error('获取用户资料失败 [' + errorNo + ']: ' + errorMsg);
      }
    } else if (tag.fieldNumber === 2) {
      const dataReader = reader.readMessage();
      while (!dataReader.isEnd()) {
        const dataTag = dataReader.readTag();
        if (dataTag.fieldNumber === 1) {
          const userReader = dataReader.readMessage();
          profile = decodeProfileUser(userReader);
        } else if (dataTag.fieldNumber === 14) {
          const agreeReader = dataReader.readMessage();
          agreeNum = decodeUserAgreeInfo(agreeReader);
        } else {
          dataReader.skipField(dataTag.wireType);
        }
      }
    } else {
      reader.skipField(tag.wireType);
    }
  }
  profile.agreeNum = agreeNum;
  return profile;
}
