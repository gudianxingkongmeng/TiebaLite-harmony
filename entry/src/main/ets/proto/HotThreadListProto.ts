// HotThreadList protobuf 编解码（对齐安卓版 HotThreadList.proto）
// 请求：HotThreadListRequest{data=1} -> HotThreadListRequestData{common=1, tabId=2, tabCode=3}
// 响应：HotThreadListResponse{error=1, data=2} -> HotThreadListResponseData{topicList=1, threadInfo=2, hotThreadTabInfo=3}

import { Dict } from '../core/types/Dict';
import { ProtoWriter, ProtoReader } from './ProtoWire';
import { ClientVersion } from '../core/network/HttpConstants';
import AccountManager from '../core/auth/AccountManager';
import DeviceFingerprint from '../core/device/DeviceFingerprint';

export interface IHotThreadListReqParams {
  tabId: string;
  tabCode: string;
}

/** 编码 CommonReq（field 编号对齐 CommonRequest.proto） */
function encodeCommonReq(writer: ProtoWriter): void {
  const device = DeviceFingerprint.getInstance();
  const account = AccountManager.getInstance().getCurrentAccountSync();

  writer.writeInt32(1, 2);
  writer.writeString(2, ClientVersion.TIEBA_V12_POST);
  writer.writeString(3, device.getClientId());
  writer.writeString(5, device.getImei());
  writer.writeString(7, device.getCuid());
  writer.writeTag(8, 0);
  writer.writeVarint(Date.now());
  writer.writeString(9, device.getModel());
  if (account) {
    writer.writeString(10, account.bduss);
    if (account.tbs) writer.writeString(11, account.tbs);
  }
  writer.writeInt32(12, device.getNetType() === 'wifi' ? 1 : 2);
  writer.writeString(25, device.getOsVersion());
  if (account) {
    writer.writeString(30, account.sToken);
  }
  writer.writeString(32, device.getCuidGalaxy2());
}

/** 编码 HotThreadListReq 顶层 */
export function encodeHotThreadListReq(params: IHotThreadListReqParams): Uint8Array {
  const writer = new ProtoWriter();
  const dataWriter = new ProtoWriter();
  const commonWriter = new ProtoWriter();
  encodeCommonReq(commonWriter);
  dataWriter.writeMessage(1, commonWriter.finish());
  dataWriter.writeString(2, params.tabId);
  dataWriter.writeString(3, params.tabCode);
  writer.writeMessage(1, dataWriter.finish());
  return writer.finish();
}

// ==================== 响应解码 ====================

/** 解析 User（field 编号对齐 User.proto） */
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

/** 解析 Media（field 编号对齐 Media.proto） */
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
  media['originSrc'] = originPic || bigPic || srcPic || smallPic;
  media['smallPic'] = smallPic;
  media['bigPic'] = bigPic;
  return media;
}

/** 解析 PbContent（field 编号对齐 PbContent.proto） */
function decodePbContent(reader: ProtoReader): Dict {
  const item: Dict = {};
  while (!reader.isEnd()) {
    const tag = reader.readTag();
    switch (tag.fieldNumber) {
      case 1: item['type'] = reader.readVarint(); break;
      case 2: item['text'] = reader.readString(); break;
      case 3: item['link'] = reader.readString(); break;
      case 4: item['src'] = reader.readString(); break;
      case 6: item['bigSrc'] = reader.readString(); break;
      case 8: item['cdnSrc'] = reader.readString(); break;
      case 9: item['bigCdnSrc'] = reader.readString(); break;
      case 11: item['c'] = reader.readString(); break;
      case 18: item['width'] = reader.readVarint(); break;
      case 19: item['height'] = reader.readVarint(); break;
      case 25: item['originSrc'] = reader.readString(); break;
      default: reader.skipField(tag.wireType); break;
    }
  }
  return item;
}

/** 解析 Abstract（field 编号对齐 Abstract.proto，其内嵌 PbContent） */
function decodeAbstract(reader: ProtoReader): Dict[] {
  const items: Dict[] = [];
  while (!reader.isEnd()) {
    const tag = reader.readTag();
    if (tag.fieldNumber === 1) {
      items.push(decodePbContent(reader.readMessage()));
    } else {
      reader.skipField(tag.wireType);
    }
  }
  return items;
}

/** 解析 VideoInfo（field 编号对齐 VideoInfo.proto） */
function decodeVideoInfo(reader: ProtoReader): Dict {
  const vi: Dict = {};
  while (!reader.isEnd()) {
    const tag = reader.readTag();
    if (tag.fieldNumber === 2) { vi['videoUrl'] = reader.readString(); }
    else if (tag.fieldNumber === 6) { vi['thumbnailUrl'] = reader.readString(); }
    else { reader.skipField(tag.wireType); }
  }
  return vi;
}

/** 解析 ThreadInfo（field 编号对齐 ThreadInfo.proto），输出 OHOS Dict 结构 */
function decodeThreadInfo(reader: ProtoReader): Dict {
  const thread: Dict = {};
  let authorReader: ProtoReader | null = null;
  let agreeReader: ProtoReader | null = null;
  const abstractItems: Dict[] = [];
  const mediaList: Dict[] = [];
  const firstPostContentList: Dict[] = [];
  let contentText: string = '';
  let videoReader: ProtoReader | null = null;

  while (!reader.isEnd()) {
    const tag = reader.readTag();
    switch (tag.fieldNumber) {
      case 1: case 2: thread['id'] = reader.readVarint(); break;
      case 3: thread['title'] = reader.readString(); break;
      case 4: thread['replyNum'] = reader.readVarint(); break;
      case 5: thread['viewNum'] = reader.readVarint(); break;
      case 6: thread['lastTime'] = reader.readString(); break;
      case 7: thread['lastTimeInt'] = reader.readVarint(); break;
      case 9: thread['isTop'] = reader.readVarint(); break;
      case 10: thread['isGood'] = reader.readVarint(); break;
      case 18: authorReader = reader.readMessage(); break;
      case 21: {
        const items = decodeAbstract(reader.readMessage());
        for (const it of items) abstractItems.push(it);
        break;
      }
      case 22: mediaList.push(decodeMedia(reader.readMessage())); break;
      case 27: thread['forumId'] = reader.readVarint(); break;
      case 28: thread['forumName'] = reader.readString(); break;
      case 45: thread['createTime'] = reader.readVarint(); break;
      case 56: thread['authorId'] = reader.readVarint(); break;
      case 79: videoReader = reader.readMessage(); break;
      case 124: thread['agreeNum'] = reader.readVarint(); break;
      case 126: agreeReader = reader.readMessage(); break;
      case 135: thread['shareNum'] = reader.readVarint(); break;
      case 142: firstPostContentList.push(decodePbContent(reader.readMessage())); break;
      case 182: thread['hotNum'] = reader.readVarint(); break;
      default: reader.skipField(tag.wireType); break;
    }
  }

  if (authorReader) { thread['author'] = decodeUser(authorReader); }
  if (videoReader) { thread['videoInfo'] = decodeVideoInfo(videoReader); }
  if (agreeReader) {
    const agree: Dict = {};
    while (!agreeReader.isEnd()) {
      const agreeTag = agreeReader.readTag();
      if (agreeTag.fieldNumber === 1) { agree['agreeNum'] = agreeReader.readVarint(); }
      else if (agreeTag.fieldNumber === 4) { agree['disagreeNum'] = agreeReader.readVarint(); }
      else { agreeReader.skipField(agreeTag.wireType); }
    }
    thread['agree'] = agree;
  }

  if (abstractItems.length > 0) {
    thread['_abstract'] = abstractItems;
    for (const it of abstractItems) {
      const c = String(it.text || it.c || '');
      if (c) contentText += c;
    }
  }
  if (firstPostContentList.length > 0) {
    thread['firstPostContent'] = firstPostContentList;
    if (!contentText) {
      for (const it of firstPostContentList) {
        const c = String(it.text || it.c || '');
        if (c) contentText += c;
      }
    }
  }
  thread['threadId'] = thread['id'];
  thread['tid'] = thread['id'];
  thread['reply_num'] = thread['replyNum'];
  thread['create_time'] = thread['createTime'];
  if (contentText) thread['content'] = contentText;
  if (mediaList.length > 0) thread['media'] = mediaList;
  if (firstPostContentList.length > 0) thread['first_post_content'] = firstPostContentList;
  return thread;
}

/** 解析 RecommendTopicList（field 编号对齐 RecommendTopicList.proto） */
function decodeTopicList(reader: ProtoReader): Dict {
  const topic: Dict = {};
  while (!reader.isEnd()) {
    const tag = reader.readTag();
    switch (tag.fieldNumber) {
      case 1: topic['topicId'] = reader.readVarint(); break;
      case 2: topic['topicName'] = reader.readString(); break;
      case 3: topic['type'] = reader.readVarint(); break;
      case 4: topic['discussNum'] = reader.readVarint(); break;
      case 5: topic['tag'] = reader.readVarint(); break;
      case 6: topic['topicDesc'] = reader.readString(); break;
      case 7: topic['topicPic'] = reader.readString(); break;
      default: reader.skipField(tag.wireType); break;
    }
  }
  return topic;
}

/** 解析 HotThreadListRes 顶层，返回含 thread_list 的 Dict */
export function decodeHotThreadListRes(bytes: Uint8Array): Dict {
  const reader = new ProtoReader(bytes);
  const threadList: Dict[] = [];
  const topicList: Dict[] = [];
  let errorCode: number = 0;
  let errorMsg: string = '';

  while (!reader.isEnd()) {
    const tag = reader.readTag();
    if (tag.fieldNumber === 1) {
      const errReader = reader.readMessage();
      while (!errReader.isEnd()) {
        const errTag = errReader.readTag();
        if (errTag.fieldNumber === 1) { errorCode = errReader.readVarint(); }
        else if (errTag.fieldNumber === 2) { errorMsg = errReader.readString(); }
        else { errReader.skipField(errTag.wireType); }
      }
    } else if (tag.fieldNumber === 2) {
      const dataReader = reader.readMessage();
      while (!dataReader.isEnd()) {
        const dataTag = dataReader.readTag();
        if (dataTag.fieldNumber === 1) {
          topicList.push(decodeTopicList(dataReader.readMessage()));
        } else if (dataTag.fieldNumber === 2) {
          threadList.push(decodeThreadInfo(dataReader.readMessage()));
        } else {
          dataReader.skipField(dataTag.wireType);
        }
      }
    } else {
      reader.skipField(tag.wireType);
    }
  }

  if (errorCode !== 0) {
    throw new Error('获取热门帖失败 [' + errorCode + ']: ' + errorMsg);
  }

  const result: Dict = {};
  result['error_code'] = '0';
  const data: Dict = {};
  data['thread_list'] = threadList;
  data['threadList'] = threadList;
  if (topicList.length > 0) data['topic_list'] = topicList;
  result['data'] = data;
  return result;
}