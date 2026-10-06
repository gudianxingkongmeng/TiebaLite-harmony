import { util } from '@kit.ArkTS';

export class ProtoTag {
  fieldNumber: number = 0;
  wireType: number = 0;
}

export class ProtoWriter {
  private buffer: number[] = [];
  private static readonly encoder: util.TextEncoder = new util.TextEncoder();

  writeVarint(value: number): void {
    if (value === 0) { this.buffer.push(0); return; }
    while (value > 0) {
      let byte: number = value % 0x80;
      value = Math.floor(value / 0x80);
      if (value > 0) { byte += 0x80; }
      this.buffer.push(byte);
    }
  }

  writeTag(fieldNumber: number, wireType: number): void {
    this.writeVarint(fieldNumber * 8 + wireType);
  }

  writeInt32(fieldNumber: number, value: number): void {
    if (value === 0) return;
    this.writeTag(fieldNumber, 0);
    if (value < 0) {
      const low32: number = value + 0x100000000;
      this.buffer.push((low32 & 0x7F) | 0x80);
      this.buffer.push(((low32 >>> 7) & 0x7F) | 0x80);
      this.buffer.push(((low32 >>> 14) & 0x7F) | 0x80);
      this.buffer.push(((low32 >>> 21) & 0x7F) | 0x80);
      this.buffer.push(((low32 >>> 28) & 0x0F) | 0x70 | 0x80);
      this.buffer.push(0xFF); this.buffer.push(0xFF); this.buffer.push(0xFF); this.buffer.push(0xFF); this.buffer.push(0x01);
    } else {
      this.writeVarint(value);
    }
  }

  writeString(fieldNumber: number, value: string): void {
    if (value.length === 0) return;
    this.writeTag(fieldNumber, 2);
    const bytes: Uint8Array = ProtoWriter.encoder.encodeInto(value);
    this.writeVarint(bytes.length);
    for (let i = 0; i < bytes.length; i++) { this.buffer.push(bytes[i]); }
  }

  writeMessage(fieldNumber: number, messageBytes: Uint8Array): void {
    this.writeTag(fieldNumber, 2);
    this.writeVarint(messageBytes.length);
    for (let i = 0; i < messageBytes.length; i++) { this.buffer.push(messageBytes[i]); }
  }

  finish(): Uint8Array {
    return new Uint8Array(this.buffer);
  }
}

export class ProtoReader {
  private buffer: Uint8Array;
  pos: number = 0;
  private static readonly decoder: util.TextDecoder = util.TextDecoder.create('utf-8');

  constructor(buffer: Uint8Array) {
    this.buffer = buffer;
  }

  readVarint(): number {
    let result: number = 0;
    let multiplier: number = 1;
    let byte: number;
    let iterCount: number = 0;
    do {
      if (this.pos >= this.buffer.length) { throw new Error('Protobuf varint overflow'); }
      byte = this.buffer[this.pos++];
      result += (byte & 0x7f) * multiplier;
      multiplier *= 0x80;
      iterCount++;
      if (iterCount > 10) { throw new Error('Protobuf varint too long'); }
    } while ((byte & 0x80) !== 0);
    return result;
  }

  readTag(): ProtoTag {
    const tag = new ProtoTag();
    const value = this.readVarint();
    tag.fieldNumber = Math.floor(value / 8);
    tag.wireType = value % 8;
    return tag;
  }

  readString(): string {
    const length = this.readVarint();
    if (length < 0 || this.pos + length > this.buffer.length) { throw new Error('Protobuf string overflow'); }
    const bytes = this.buffer.subarray(this.pos, this.pos + length);
    this.pos += length;
    const result: string = ProtoReader.decoder.decodeWithStream(bytes);
    return result || '';
  }

  readMessage(): ProtoReader {
    const length = this.readVarint();
    if (length < 0 || this.pos + length > this.buffer.length) { throw new Error('Protobuf message overflow'); }
    const bytes = this.buffer.subarray(this.pos, this.pos + length);
    this.pos += length;
    return new ProtoReader(bytes);
  }

  skipField(wireType: number): void {
    if (wireType === 0) { this.readVarint(); }
    else if (wireType === 1) { this.pos += 8; }
    else if (wireType === 2) { const len = this.readVarint(); this.pos += len; }
    else if (wireType === 5) { this.pos += 4; }
  }

  isEnd(): boolean {
    return this.pos >= this.buffer.length;
  }
}
