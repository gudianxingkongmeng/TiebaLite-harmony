import { ProtoReader, ProtoWriter } from './ProtoWire';
import { decodePollInfo, PollData } from './PollProto';

/**
 * 编码 pbPage 请求（PbPageRequest.proto）：
 * data=1 内：kz=4(tid)、lz=5、r=6(sort)、rn=13、pn=18、common=25(_client_type=2,_client_version)
 */
export function encodePbPageReq(tid: number, pn: number, sort: number, onlyAuthor: boolean, clientVersion: string): Uint8Array {
  const dataWriter = new ProtoWriter();
  dataWriter.writeTag(4, 0);
  dataWriter.writeVarint(tid);
  dataWriter.writeInt32(5, onlyAuthor ? 1 : 0);
  dataWriter.writeInt32(6, sort);
  dataWriter.writeInt32(13, 30);
  dataWriter.writeInt32(18, pn);
  // common (field 25)
  const commonWriter = new ProtoWriter();
  commonWriter.writeTag(1, 0);          // _client_type
  commonWriter.writeVarint(2);
  commonWriter.writeString(2, clientVersion);  // _client_version
  dataWriter.writeMessage(25, commonWriter.finish());
  const writer = new ProtoWriter();
  writer.writeMessage(1, dataWriter.finish());
  return writer.finish();
}

/**
 * 从 pbPage 响应提取 poll_info（不解码 posts）：
 * data(2) → thread(8) → origin_thread_info(141) → poll_info(21)
 * 返回 null 表示无投票
 */
export function decodePollInfoFromPbPage(bytes: Uint8Array): PollData | null {
  const reader = new ProtoReader(bytes);
  while (!reader.isEnd()) {
    const tag = reader.readTag();
    if (tag.fieldNumber === 2) {                 // data
      const dataReader = reader.readMessage();
      while (!dataReader.isEnd()) {
        const dataTag = dataReader.readTag();
        if (dataTag.fieldNumber === 8) {         // thread (ThreadInfo)
          const threadReader = dataReader.readMessage();
          while (!threadReader.isEnd()) {
            const threadTag = threadReader.readTag();
            if (threadTag.fieldNumber === 141) { // origin_thread_info
              const originReader = threadReader.readMessage();
              while (!originReader.isEnd()) {
                const originTag = originReader.readTag();
                if (originTag.fieldNumber === 21) { // poll_info
                  return decodePollInfo(originReader.readMessage());
                } else {
                  originReader.skipField(originTag.wireType);
                }
              }
            } else {
              threadReader.skipField(threadTag.wireType);
            }
          }
        } else {
          dataReader.skipField(dataTag.wireType);
        }
      }
    } else {
      reader.skipField(tag.wireType);
    }
  }
  return null;
}
