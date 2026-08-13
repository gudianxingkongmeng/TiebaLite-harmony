import { ProtoWriter, ProtoReader } from './ProtoWire';
import DeviceFingerprint from '../core/device/DeviceFingerprint';
import { Account } from '../core/auth/AccountManager';

const ADD_POST_VERSION: string = '12.35.1.0';

export interface IAddPostReqParams {
  content: string;
  forumId: string;
  forumName: string;
  threadId: string;
  tbs: string;
  account: Account;
  nameShow: string;
  postId?: string;
  subPostId?: string;
  replyUid?: string;
}

function formatEventDay(ts: number): string {
  const d = new Date(ts);
  return d.getFullYear() + String(d.getMonth() + 1) + String(d.getDate());
}

function encodeCommonReq(writer: ProtoWriter, params: IAddPostReqParams): void {
  const device = DeviceFingerprint.getInstance();
  const nowMs: number = Date.now();
  const nowSec: number = Math.floor(nowMs / 1000);
  writer.writeInt32(1, 2);
  writer.writeString(2, ADD_POST_VERSION);
  if (device.getClientId().length > 0) { writer.writeString(3, device.getClientId()); }
  if (device.getImei().length > 0) { writer.writeString(5, device.getImei()); }
  writer.writeString(6, '1008621x');
  if (device.getCuid().length > 0) { writer.writeString(7, device.getCuid()); }
  writer.writeTag(8, 0); writer.writeVarint(nowMs);
  if (device.getModel().length > 0) { writer.writeString(9, device.getModel()); }
  if (params.account.bduss.length > 0) { writer.writeString(10, params.account.bduss); }
  if (params.tbs.length > 0) { writer.writeString(11, params.tbs); }
  writer.writeInt32(12, 1);
  writer.writeString(24, '1.0.3');
  if (device.getOsVersion().length > 0) { writer.writeString(25, device.getOsVersion()); }
  if (device.getBrand().length > 0) { writer.writeString(26, device.getBrand()); }
  writer.writeString(28, '3.0.0');
  writer.writeString(29, '');
  if (params.account.sToken.length > 0) { writer.writeString(30, params.account.sToken); }
  if (device.getZid().length > 0) { writer.writeString(31, device.getZid()); }
  if (device.getCuidGalaxy2().length > 0) { writer.writeString(32, device.getCuidGalaxy2()); }
  writer.writeString(33, '');
  writer.writeString(35, 'A00-ZNU3O3EP74D727LMQY745CZSGZQJQZGP-3JXCKC7X');
  if (device.getSampleId().length > 0) { writer.writeString(36, device.getSampleId()); }
  writer.writeInt32(37, device.getScreenWidth());
  writer.writeInt32(38, device.getScreenHeight());
  writer.writeInt32(40, 0);
  writer.writeInt32(41, 0);
  writer.writeString(42, '2.34.0');
  writer.writeString(43, '3340042');
  writer.writeString(44, '1038000');
  writer.writeTag(49, 0); writer.writeVarint(nowSec - 86400 * 30);
  writer.writeTag(50, 0); writer.writeVarint(nowSec - 86400 * 30);
  writer.writeTag(51, 0); writer.writeVarint(nowSec - 86400);
  writer.writeString(53, formatEventDay(nowMs));
  if (device.getAndroidId().length > 0) { writer.writeString(54, device.getAndroidId()); }
  writer.writeInt32(55, 1);
  writer.writeString(56, '');
  writer.writeInt32(57, 1);
  writer.writeString(61, '');
  writer.writeString(62, 'bdtb for Android ' + ADD_POST_VERSION);
  writer.writeInt32(63, 1);
  writer.writeString(70, '0.4');
}

function encodeDataReq(params: IAddPostReqParams): Uint8Array {
  const writer = new ProtoWriter();
  const commonWriter = new ProtoWriter();
  encodeCommonReq(commonWriter, params);
  writer.writeMessage(1, commonWriter.finish());
  writer.writeString(6, '1');
  writer.writeString(7, '0');
  writer.writeString(8, '0');
  writer.writeString(9, '0');
  writer.writeString(10, '0');
  writer.writeString(16, '12');
  writer.writeString(18, '1');
  writer.writeString(19, params.content);
  if (params.replyUid && params.replyUid.length > 0) { writer.writeString(20, params.replyUid); }
  writer.writeString(26, params.forumId);
  writer.writeString(30, params.forumName);
  writer.writeString(31, '0');
  writer.writeString(44, params.forumId);
  writer.writeString(45, params.threadId);
  if (params.postId && params.postId.length > 0) {
    writer.writeString(46, params.postId);
    writer.writeString(49, params.postId);
  }
  writer.writeString(47, '0');
  writer.writeString(48, '0');
  if (params.subPostId && params.subPostId.length > 0) { writer.writeString(50, params.subPostId); }
  writer.writeString(51, '0');
  writer.writeString(52, '0');
  writer.writeString(53, '0');
  if (params.postId && params.postId.length > 0) {
    if (params.subPostId && params.subPostId.length > 0) {
      // 楼中楼回复：不携带 post_from
    } else {
      writer.writeString(55, '0');
    }
  } else {
    writer.writeString(55, '13');
    writer.writeString(32, '0');
  }
  if (params.nameShow.length > 0) { writer.writeString(58, params.nameShow); }
  writer.writeString(60, '0');
  writer.writeInt32(64, 0);
  writer.writeInt32(67, 0);
  return writer.finish();
}

export function encodeAddPostReq(params: IAddPostReqParams): Uint8Array {
  const writer = new ProtoWriter();
  const dataBytes = encodeDataReq(params);
  writer.writeMessage(1, dataBytes);
  return writer.finish();
}

export interface IAddPostRes {
  errorNo: number;
  errorMsg: string;
  pid: number;
  tid: number;
}

export function decodeAddPostRes(bytes: Uint8Array): IAddPostRes {
  const reader = new ProtoReader(bytes);
  const result: IAddPostRes = { errorNo: 0, errorMsg: '', pid: 0, tid: 0 };
  while (!reader.isEnd()) {
    const tag = reader.readTag();
    if (tag.fieldNumber === 1) {
      const errReader = reader.readMessage();
      while (!errReader.isEnd()) {
        const errTag = errReader.readTag();
        if (errTag.fieldNumber === 1) { result.errorNo = errReader.readVarint(); }
        else if (errTag.fieldNumber === 2) { result.errorMsg = errReader.readString(); }
        else { errReader.skipField(errTag.wireType); }
      }
    } else if (tag.fieldNumber === 2) {
      const dataReader = reader.readMessage();
      while (!dataReader.isEnd()) {
        const dataTag = dataReader.readTag();
        if (dataTag.fieldNumber === 2) {
          result.tid = dataTag.wireType === 0 ? dataReader.readVarint() : Number(dataReader.readString());
        } else if (dataTag.fieldNumber === 3) {
          result.pid = dataTag.wireType === 0 ? dataReader.readVarint() : Number(dataReader.readString());
        } else { dataReader.skipField(dataTag.wireType); }
      }
    } else { reader.skipField(tag.wireType); }
  }
  return result;
}
