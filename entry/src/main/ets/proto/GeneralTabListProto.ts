// GeneralTabList protobuf 编解码（对齐 02 工程已验证实现 / Android GeneralTabListRequestData.proto）
// 端点：POST /c/f/frs/generalTabList?cmd=309622&format=protobuf
// 用途：贴吧分区（吧友互助/吐槽/新闻/生活等 nav_tab）帖子列表
// 字段编号对齐 Android：common=1 / tab_id=2 / forum_id=3 / pn=4 / rn=5 / last_thread_id=9 /
//   is_default_navtab=10 / tab_name=11 / is_general_tab=12 / sort_type=13 / tab_type=14 / is_newfrs=22
// 响应：GeneralTabListResponseData：general_list=1（repeated ThreadInfo）/ has_more=2 / user_list=3

import { Dict } from '../core/types/Dict';
import { ProtoWriter, ProtoReader } from './ProtoWire';

/** GeneralTabList 请求参数 */
export interface IGeneralTabListReqParams {
  forumId: number;
  tabId: number;
  tabName: string;
  tabType: number;
  isGeneralTab: number;
  pn: number;
  rn: number;
  sortType: number;
  lastThreadId: number;
}

const CLIENT_VERSION: string = '12.64.1.1';

/** 编码 CommonReq（field 编号对齐 CommonRequest.proto，与 FrsPage 一致） */
function encodeCommonReq(writer: ProtoWriter): void {
  writer.writeInt32(1, 2);                     // _client_type = 2
  writer.writeString(2, CLIENT_VERSION);       // _client_version
}

/** 编码 DataReq */
function encodeDataReq(params: IGeneralTabListReqParams): Uint8Array {
  const writer = new ProtoWriter();

  const commonWriter = new ProtoWriter();
  encodeCommonReq(commonWriter);
  writer.writeMessage(1, commonWriter.finish());

  writer.writeInt32(2, params.tabId);                  // tab_id
  writer.writeTag(3, 0); writer.writeVarint(params.forumId);   // forum_id
  writer.writeInt32(4, params.pn);                     // pn
  writer.writeInt32(5, params.rn);                     // rn
  if (params.lastThreadId > 0) {
    writer.writeTag(9, 0); writer.writeVarint(params.lastThreadId);   // last_thread_id
  }
  writer.writeInt32(10, params.isGeneralTab);          // is_default_navtab
  writer.writeString(11, params.tabName);              // tab_name
  writer.writeInt32(12, params.isGeneralTab);          // is_general_tab
  writer.writeInt32(13, params.sortType);              // sort_type（0=按回复 1=按发布）
  writer.writeInt32(14, params.tabType);               // tab_type
  writer.writeInt32(22, 1);                            // is_newfrs

  return writer.finish();
}

/** 编码 GeneralTabListReqIdl 顶层 */
export function encodeGeneralTabListReq(params: IGeneralTabListReqParams): Uint8Array {
  const writer = new ProtoWriter();
  const dataBytes = encodeDataReq(params);
  writer.writeMessage(1, dataBytes);  // data
  return writer.finish();
}

// ==================== 响应解码 ====================

/** 解析 User（field 编号对齐 User.proto） */
function decodeUser(reader: ProtoReader): Dict {
  const user: Dict = {};
  while (!reader.isEnd()) {
    const tag = reader.readTag();
    switch (tag.fieldNumber) {
      case 2:   // id
        user['id'] = reader.readVarint();
        user['uid'] = user['id'];
        break;
      case 3:   // name
        user['name'] = reader.readString();
        break;
      case 4:   // name_show
        user['nameShow'] = reader.readString();
        user['name_show'] = user['nameShow'];
        break;
      case 5:   // portrait
        user['portrait'] = reader.readString();
        break;
      case 23:  // level_id
        user['level'] = reader.readVarint();
        break;
      default:
        reader.skipField(tag.wireType);
        break;
    }
  }
  return user;
}

/** 解析 Media（field 编号对齐 Media.proto） */
function decodeMedia(reader: ProtoReader): Dict {
  const media: Dict = {};
  let smallPic: string = '';
  let bigPic: string = '';
  let srcPic: string = '';
  let originPic: string = '';

  while (!reader.isEnd()) {
    const tag = reader.readTag();
    switch (tag.fieldNumber) {
      case 1:   // type
        media['type'] = reader.readVarint();
        break;
      case 2:   // small_pic
        smallPic = reader.readString();
        break;
      case 3:   // big_pic
        bigPic = reader.readString();
        break;
      case 8:   // src_pic
        srcPic = reader.readString();
        break;
      case 10:  // width
        media['width'] = reader.readVarint();
        break;
      case 11:  // height
        media['height'] = reader.readVarint();
        break;
      case 15:  // origin_pic
        originPic = reader.readString();
        break;
      default:
        reader.skipField(tag.wireType);
        break;
    }
  }

  let url: string = smallPic;
  if (originPic.length > 0) {
    url = originPic;
  } else if (bigPic.length > 0) {
    url = bigPic;
  } else if (srcPic.length > 0) {
    url = srcPic;
  }
  media['src'] = url;
  media['originSrc'] = url;
  return media;
}

/** 解析 Thread（field 编号对齐 ThreadInfo.proto），输出 04 工程 Dict 结构 */
function decodeThread(reader: ProtoReader, users: Map<string, Dict>, forumName: string): Dict {
  const thread: Dict = {};
  let authorId: number = 0;
  let tid: number = 0;
  let title: string = '';
  let replyNum: number = 0;
  let viewNum: number = 0;
  let createTime: number = 0;
  let agreeNum: number = 0;
  let disagreeNum: number = 0;
  let hotNum: number = 0;
  let isTop: number = 0;
  let isGood: number = 0;
  let content: string = '';
  const mediaList: Dict[] = [];

  while (!reader.isEnd()) {
    const tag = reader.readTag();
    switch (tag.fieldNumber) {
      case 1:   // id
        tid = reader.readVarint();
        break;
      case 2:   // threadId
        tid = reader.readVarint();
        break;
      case 3:   // title
        title = reader.readString();
        break;
      case 4:   // reply_num
        replyNum = reader.readVarint();
        break;
      case 5:   // view_num
        viewNum = reader.readVarint();
        break;
      case 9:   // is_top
        isTop = reader.readVarint();
        break;
      case 10:  // is_good
        isGood = reader.readVarint();
        break;
      case 18: {  // author（内嵌 User）
        const authorReader = reader.readMessage();
        thread['author'] = decodeUser(authorReader);
        break;
      }
      case 21: {  // _abstract（repeated，拼 text 字段作为正文摘要）
        const absReader = reader.readMessage();
        while (!absReader.isEnd()) {
          const absTag = absReader.readTag();
          if (absTag.fieldNumber === 2) {  // text
            content += absReader.readString();
          } else {
            absReader.skipField(absTag.wireType);
          }
        }
        break;
      }
      case 22: {  // media（repeated）
        const mediaReader = reader.readMessage();
        mediaList.push(decodeMedia(mediaReader));
        break;
      }
      case 28:  // forum_name
        thread['forumName'] = reader.readString();
        break;
      case 45:  // create_time
        createTime = reader.readVarint();
        break;
      case 56:  // author_id
        authorId = reader.readVarint();
        break;
      case 126: {  // agree（Agree: agree_num=1, disagree_num=4）
        const agreeReader = reader.readMessage();
        while (!agreeReader.isEnd()) {
          const agreeTag = agreeReader.readTag();
          if (agreeTag.fieldNumber === 1) {
            agreeNum = agreeReader.readVarint();
          } else if (agreeTag.fieldNumber === 4) {
            disagreeNum = agreeReader.readVarint();
          } else {
            agreeReader.skipField(agreeTag.wireType);
          }
        }
        break;
      }
      case 182:  // hot_num
        hotNum = reader.readVarint();
        break;
      default:
        reader.skipField(tag.wireType);
        break;
    }
  }

  if (authorId > 0) {
    const u = users.get(String(authorId));
    if (u !== undefined) {
      thread['author'] = u;
    }
  }

  thread['id'] = tid;
  thread['tid'] = tid;
  thread['threadId'] = tid;
  thread['title'] = title;
  thread['replyNum'] = replyNum;
  thread['reply_num'] = replyNum;
  thread['viewNum'] = viewNum;
  thread['view_num'] = viewNum;
  thread['is_top'] = isTop;
  thread['isTop'] = isTop;
  thread['is_good'] = isGood;
  thread['isGood'] = isGood;
  thread['createTime'] = createTime;
  thread['create_time'] = createTime;
  thread['lastTimeInt'] = createTime;
  thread['agree'] = { agreeNum: agreeNum, disagreeNum: disagreeNum };
  thread['agreeNum'] = agreeNum;
  thread['agree_num'] = agreeNum;
  thread['hotNum'] = hotNum;
  thread['hot_num'] = hotNum;
  thread['forumName'] = forumName;
  if (mediaList.length > 0) {
    thread['media'] = mediaList;
  }
  if (content.length > 0) {
    thread['_abstract'] = [{ type: 2, text: content }];
    thread['content'] = content;
  }
  return thread;
}

/** GeneralTabList 解析结果 */
export class GeneralTabListResult {
  threads: Dict[] = [];
  hasMore: boolean = false;
}

/** 解析 GeneralTabListResIdl 顶层 */
export function decodeGeneralTabListRes(bytes: Uint8Array, forumName: string): GeneralTabListResult {
  const reader = new ProtoReader(bytes);
  const result = new GeneralTabListResult();

  while (!reader.isEnd()) {
    const tag = reader.readTag();
    if (tag.fieldNumber === 1) {
      // error
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
        throw new Error(`获取分区帖子列表失败 [${errorNo}]: ${errorMsg}`);
      }
    } else if (tag.fieldNumber === 2) {
      // data
      const dataReader = reader.readMessage();
      const users: Map<string, Dict> = new Map();
      const rawThreads: ProtoReader[] = [];

      // 第一遍：收集 general_list 的 raw bytes + has_more + user_list
      while (!dataReader.isEnd()) {
        const dataTag = dataReader.readTag();
        if (dataTag.fieldNumber === 1) {
          rawThreads.push(dataReader.readMessage());
        } else if (dataTag.fieldNumber === 2) {
          result.hasMore = dataReader.readVarint() !== 0;
        } else if (dataTag.fieldNumber === 3) {
          const userReader = dataReader.readMessage();
          const user = decodeUser(userReader);
          const uid = user['id'] as number;
          if (uid > 0) {
            users.set(String(uid), user);
          }
        } else {
          dataReader.skipField(dataTag.wireType);
        }
      }

      // 第二遍：解码 threads（user_list 已全部填充，author 关联可靠）
      for (let i = 0; i < rawThreads.length; i++) {
        result.threads.push(decodeThread(rawThreads[i], users, forumName));
      }
    } else {
      reader.skipField(tag.wireType);
    }
  }

  return result;
}
