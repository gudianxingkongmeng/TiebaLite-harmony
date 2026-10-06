import { ProtoReader, ProtoWriter } from './ProtoWire';

export interface PollOptionData {
  id: number;
  num: number;
  text: string;
  image: string;
}

export interface PollData {
  title: string;
  isMulti: boolean;
  totalPoll: number;
  endTime: number;
  polledValue: number[];
  options: PollOptionData[];
  isPolled: boolean;
  isLoading: boolean;
}

export function emptyPollData(): PollData {
  return {
    title: '',
    isMulti: false,
    totalPoll: 0,
    endTime: 0,
    polledValue: [],
    options: [],
    isPolled: false,
    isLoading: false
  };
}

/**
 * 解码 PollInfo（PollInfo.proto）：
 * type=1, is_multi=2, total_num=3, options_count=4, is_polled=5, polled_value=6(逗号分隔)
 * tips=7, end_time=8(秒), options=9(repeated), status=10, total_poll=11, title=12, last_time=13
 */
export function decodePollInfo(reader: ProtoReader): PollData {
  const result = emptyPollData();
  let endTimeSeconds: number = 0;
  while (!reader.isEnd()) {
    const tag = reader.readTag();
    if (tag.fieldNumber === 2) {
      result.isMulti = reader.readVarint() !== 0;
    } else if (tag.fieldNumber === 6) {
      const value = reader.readString();
      if (value.length > 0) {
        const parts = value.split(',');
        for (let i = 0; i < parts.length; i++) {
          const id = parseInt(parts[i], 10);
          if (!Number.isNaN(id)) { result.polledValue.push(id); }
        }
      }
    } else if (tag.fieldNumber === 8) {
      endTimeSeconds = reader.readVarint();
    } else if (tag.fieldNumber === 9) {
      const optionReader = reader.readMessage();
      const option: PollOptionData = { id: 0, num: 0, text: '', image: '' };
      while (!optionReader.isEnd()) {
        const ot = optionReader.readTag();
        if (ot.fieldNumber === 1) { option.id = optionReader.readVarint(); }
        else if (ot.fieldNumber === 2) { option.num = optionReader.readVarint(); }
        else if (ot.fieldNumber === 3) { option.text = optionReader.readString(); }
        else if (ot.fieldNumber === 4) { option.image = optionReader.readString(); }
        else { optionReader.skipField(ot.wireType); }
      }
      result.options.push(option);
    } else if (tag.fieldNumber === 11) {
      result.totalPoll = reader.readVarint();
    } else if (tag.fieldNumber === 12) {
      result.title = reader.readString();
    } else {
      reader.skipField(tag.wireType);
    }
  }
  result.endTime = endTimeSeconds * 1000;
  result.isPolled = result.polledValue.length > 0;
  return result;
}

/**
 * 编码 AddPollPostRequest（AddPollPostRequest.proto）：
 * data=1 内：thread_id=1(uint64)、options=2(逗号分隔 id 串)、forum_id=4(uint64)
 */
export function encodeAddPollPostReq(forumId: number, tid: number, options: string): Uint8Array {
  const dataWriter = new ProtoWriter();
  dataWriter.writeTag(1, 0);
  dataWriter.writeVarint(tid);
  dataWriter.writeString(2, options);
  if (forumId > 0) {
    dataWriter.writeTag(4, 0);
    dataWriter.writeVarint(forumId);
  }
  const writer = new ProtoWriter();
  writer.writeMessage(1, dataWriter.finish());
  return writer.finish();
}

/**
 * 将 proto 解码出的 PollData 转为 PollCard 可渲染的 JSON 风格 Dict。
 * 键名对齐 JSON pbPage 的 poll_info（title/options/total_poll/end_time/is_multi/polled_value）
 */
export function pollDataToDict(poll: PollData): Record<string, any> {
  const options: any[] = [];
  for (let i = 0; i < poll.options.length; i++) {
    const o = poll.options[i];
    options.push({ id: o.id, num: o.num, text: o.text, image: o.image });
  }
  return {
    title: poll.title,
    options: options,
    total_poll: poll.totalPoll,
    end_time: Math.floor(poll.endTime / 1000),
    is_multi: poll.isMulti ? 1 : 0,
    polled_value: poll.polledValue.join(',')
  };
}

/**
 * 解码 AddPollPostReponse：data=1(error_code=1,error_msg=2) 或 error=2(errorno=1,errmsg=2)，非 0 抛错
 */
export function decodeAddPollPostRes(bytes: Uint8Array): void {
  const reader = new ProtoReader(bytes);
  while (!reader.isEnd()) {
    const tag = reader.readTag();
    if (tag.fieldNumber === 1) {
      const dataReader = reader.readMessage();
      let errorCode: number = 0;
      let errorMsg: string = '';
      while (!dataReader.isEnd()) {
        const dt = dataReader.readTag();
        if (dt.fieldNumber === 1) { errorCode = dataReader.readVarint(); }
        else if (dt.fieldNumber === 2) { errorMsg = dataReader.readString(); }
        else { dataReader.skipField(dt.wireType); }
      }
      if (errorCode !== 0) { throw new Error('投票失败 [' + errorCode + ']: ' + errorMsg); }
    } else if (tag.fieldNumber === 2) {
      const errReader = reader.readMessage();
      let errorNo: number = 0;
      let errorMsg: string = '';
      while (!errReader.isEnd()) {
        const et = errReader.readTag();
        if (et.fieldNumber === 1) { errorNo = errReader.readVarint(); }
        else if (et.fieldNumber === 2) { errorMsg = errReader.readString(); }
        else { errReader.skipField(et.wireType); }
      }
      if (errorNo !== 0) { throw new Error('投票失败 [' + errorNo + ']: ' + errorMsg); }
    } else {
      reader.skipField(tag.wireType);
    }
  }
}
