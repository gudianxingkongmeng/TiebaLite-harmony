import { Dict } from '../core/types/Dict';
import { ProtoWriter, ProtoReader } from './ProtoWire';

export interface IUserLikeReqParams {
  pageTag: string;
  lastRequestUnix: number;
  loadType: number;
  bduss: string;
  cuid: string;
  timestamp: number;
  netType: number;
  stoken: string;
}

const STABLE_VERSION: string = '12.64.1.1';

function encodeCommonReq(writer: ProtoWriter, params: IUserLikeReqParams): void {
  writer.writeInt32(1, 2);
  writer.writeString(2, STABLE_VERSION);
  if (params.cuid.length > 0) { writer.writeString(7, params.cuid); }
  if (params.timestamp > 0) { writer.writeTag(8, 0); writer.writeVarint(params.timestamp); }
  if (params.bduss.length > 0) { writer.writeString(10, params.bduss); }
  writer.writeInt32(12, params.netType);
  if (params.stoken.length > 0) { writer.writeString(30, params.stoken); }
}

export function encodeUserLikeReq(params: IUserLikeReqParams): Uint8Array {
  const writer = new ProtoWriter();
  const dataWriter = new ProtoWriter();
  const commonWriter = new ProtoWriter();
  encodeCommonReq(commonWriter, params);
  dataWriter.writeMessage(1, commonWriter.finish());
  dataWriter.writeString(2, params.pageTag);
  if (params.lastRequestUnix > 0) { dataWriter.writeTag(3, 0); dataWriter.writeVarint(params.lastRequestUnix); }
  dataWriter.writeInt32(4, 1);
  dataWriter.writeInt32(5, params.loadType);
  writer.writeMessage(1, dataWriter.finish());
  return writer.finish();
}

function decodeUser(reader: ProtoReader): Dict {
  const user: Dict = {};
  while (!reader.isEnd()) {
    const tag = reader.readTag();
    switch (tag.fieldNumber) {
      case 2: user['id'] = reader.readVarint(); break;
      case 3: user['name'] = reader.readString(); break;
      case 4: user['nameShow'] = reader.readString(); break;
      case 5: user['portrait'] = reader.readString(); break;
      default: reader.skipField(tag.wireType); break;
    }
  }
  return user;
}

function decodeMedia(reader: ProtoReader): Dict {
  const media: Dict = {};
  let smallPic: string = ''; let bigPic: string = ''; let srcPic: string = ''; let originPic: string = '';
  while (!reader.isEnd()) {
    const tag = reader.readTag();
    switch (tag.fieldNumber) {
      case 1: media['type'] = reader.readVarint(); break;
      case 2: smallPic = reader.readString(); break;
      case 3: bigPic = reader.readString(); break;
      case 8: srcPic = reader.readString(); break;
      case 10: media['width'] = reader.readVarint(); break;
      case 11: media['height'] = reader.readVarint(); break;
      case 15: originPic = reader.readString(); break;
      default: reader.skipField(tag.wireType); break;
    }
  }
  media['src'] = originPic || bigPic || srcPic || smallPic;
  media['originSrc'] = originPic;
  media['bigPic'] = bigPic;
  media['smallPic'] = smallPic;
  return media;
}

function decodeThread(reader: ProtoReader): Dict {
  const thread: Dict = {};
  let authorReader: ProtoReader | null = null;
  let agreeNum: number = 0;
  let createTime: number = 0;
  let contentText: string = '';
  let forumName: string = '';
  const mediaList: Dict[] = [];
  while (!reader.isEnd()) {
    const tag = reader.readTag();
    switch (tag.fieldNumber) {
      case 1: case 2: thread['id'] = reader.readVarint(); break;
      case 3: thread['title'] = reader.readString(); break;
      case 4: thread['replyNum'] = reader.readVarint(); break;
      case 18: authorReader = reader.readMessage(); break;
      case 21: {
        const absReader = reader.readMessage();
        while (!absReader.isEnd()) {
          const absTag = absReader.readTag();
          if (absTag.fieldNumber === 2) { contentText += absReader.readString(); }
          else { absReader.skipField(absTag.wireType); }
        }
        break;
      }
      case 22: { const mReader = reader.readMessage(); mediaList.push(decodeMedia(mReader)); break; }
      case 28: forumName = reader.readString(); break;
      case 45: createTime = reader.readVarint(); break;
      case 79: {
        const vReader = reader.readMessage();
        const vi: Dict = {};
        while (!vReader.isEnd()) {
          const vTag = vReader.readTag();
          if (vTag.fieldNumber === 2) { vi['videoUrl'] = vReader.readString(); }
          else if (vTag.fieldNumber === 6) { vi['thumbnailUrl'] = vReader.readString(); }
          else { vReader.skipField(vTag.wireType); }
        }
        thread['videoInfo'] = vi;
        break;
      }
      case 126: {
        const agreeReader = reader.readMessage();
        while (!agreeReader.isEnd()) {
          const agreeTag = agreeReader.readTag();
          if (agreeTag.fieldNumber === 1) { agreeNum = agreeReader.readVarint(); }
          else { agreeReader.skipField(agreeTag.wireType); }
        }
        break;
      }
      case 182: thread['hotNum'] = reader.readVarint(); break;
      default: reader.skipField(tag.wireType); break;
    }
  }
  if (authorReader) { thread['author'] = decodeUser(authorReader); }
  thread['agreeNum'] = agreeNum;
  thread['createTime'] = createTime;
  thread['forumName'] = forumName;
  if (contentText.length > 0) { thread['_abstract'] = contentText; thread['firstPostContent'] = contentText; }
  if (mediaList.length > 0) { thread['media'] = mediaList; }
  return thread;
}

export function decodeUserLikeRes(bytes: Uint8Array): Dict {
  const reader = new ProtoReader(bytes);
  let errorCode: string = '0';
  const concernDataList: Dict[] = [];
  let pageTag: string = '';
  let hasMore: number = 0;
  let requestUnix: number = 0;
  while (!reader.isEnd()) {
    const tag = reader.readTag();
    if (tag.fieldNumber === 1) {
      const errReader = reader.readMessage();
      let errNo: number = 0; let errMsg: string = '';
      while (!errReader.isEnd()) {
        const errTag = errReader.readTag();
        if (errTag.fieldNumber === 1) { errNo = errReader.readVarint(); }
        else if (errTag.fieldNumber === 2) { errMsg = errReader.readString(); }
        else { errReader.skipField(errTag.wireType); }
      }
      if (errNo !== 0) { throw new Error('获取动态失败 [' + errNo + ']: ' + errMsg); }
    } else if (tag.fieldNumber === 2) {
      const dataReader = reader.readMessage();
      while (!dataReader.isEnd()) {
        const dataTag = dataReader.readTag();
        if (dataTag.fieldNumber === 1) {
          const concernReader = dataReader.readMessage();
          let thread: Dict | null = null;
          let recommendType: number = 0;
          while (!concernReader.isEnd()) {
            const cTag = concernReader.readTag();
            if (cTag.fieldNumber === 1) { const tr = concernReader.readMessage(); thread = decodeThread(tr); }
            else if (cTag.fieldNumber === 3) { recommendType = concernReader.readVarint(); }
            else { concernReader.skipField(cTag.wireType); }
          }
          if (thread && recommendType === 1) {
            const item: Dict = {};
            item['recommendType'] = 1;
            item['threadList'] = thread;
            concernDataList.push(item);
          }
        } else if (dataTag.fieldNumber === 2) { pageTag = dataReader.readString(); }
        else if (dataTag.fieldNumber === 4) { hasMore = dataReader.readVarint(); }
        else if (dataTag.fieldNumber === 10) { requestUnix = dataReader.readVarint(); }
        else { dataReader.skipField(dataTag.wireType); }
      }
    } else { reader.skipField(tag.wireType); }
  }
  const innerData: Dict = {};
  innerData['threadInfo'] = concernDataList;
  innerData['pageTag'] = pageTag;
  innerData['hasMore'] = hasMore;
  innerData['requestUnix'] = requestUnix;
  const result: Dict = {};
  result['error_code'] = errorCode;
  result['data'] = innerData;
  return result;
}
