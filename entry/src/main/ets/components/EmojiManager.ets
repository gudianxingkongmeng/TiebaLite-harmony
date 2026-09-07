import { Dict } from '../core/types/Dict';

export class EmoticonInfo {
  id: string = '';
  name: string = '';
}

let emojiNameMap: Record<string, string> = {
  '呵呵': 'image_emoticon1', '哈哈': 'image_emoticon2', '吐舌': 'image_emoticon3',
  '啊': 'image_emoticon4', '酷': 'image_emoticon5', '怒': 'image_emoticon6',
  '开心': 'image_emoticon7', '汗': 'image_emoticon8', '泪': 'image_emoticon9',
  '黑线': 'image_emoticon10', '鄙视': 'image_emoticon11', '不高兴': 'image_emoticon12',
  '真棒': 'image_emoticon13', '钱': 'image_emoticon14', '疑问': 'image_emoticon15',
  '阴险': 'image_emoticon16', '吐': 'image_emoticon17', '咦': 'image_emoticon18',
  '委屈': 'image_emoticon19', '花心': 'image_emoticon20', '呼~': 'image_emoticon21',
  '笑眼': 'image_emoticon22', '冷': 'image_emoticon23', '太开心': 'image_emoticon24',
  '滑稽': 'image_emoticon25', '勉强': 'image_emoticon26', '狂汗': 'image_emoticon27',
  '乖': 'image_emoticon28', '睡觉': 'image_emoticon29', '惊哭': 'image_emoticon30',
  '生气': 'image_emoticon31', '惊讶': 'image_emoticon32', '喷': 'image_emoticon33',
  '爱心': 'image_emoticon34', '心碎': 'image_emoticon35', '玫瑰': 'image_emoticon36',
  '礼物': 'image_emoticon37', '彩虹': 'image_emoticon38', '星星月亮': 'image_emoticon39',
  '太阳': 'image_emoticon40', '钱币': 'image_emoticon41', '灯泡': 'image_emoticon42',
  '茶杯': 'image_emoticon43', '蛋糕': 'image_emoticon44', '音乐': 'image_emoticon45',
  'haha': 'image_emoticon46', '胜利': 'image_emoticon47', '大拇指': 'image_emoticon48',
  '弱': 'image_emoticon49', 'OK': 'image_emoticon50', '沙发': 'image_emoticon77',
  '手纸': 'image_emoticon78', '香蕉': 'image_emoticon79', '便便': 'image_emoticon80',
  '药丸': 'image_emoticon81', '红领巾': 'image_emoticon82', '蜡烛': 'image_emoticon83',
  '三道杠': 'image_emoticon84'
};

export function getAllEmoticons(): EmoticonInfo[] {
  const result: EmoticonInfo[] = [];
  const entries = Object.entries(emojiNameMap);
  for (let i = 0; i < entries.length; i++) {
    const entry = entries[i];
    const name = entry[0] as string;
    const id = entry[1] as string;
    result.push({ id, name });
  }
  return result;
}

export function registerEmoji(name: string, id: string): void {
  if (name && id && name !== id) {
    emojiNameMap[name] = id;
  }
}

export function getEmojiIdFromMap(name: string): string | undefined {
  return emojiNameMap[name];
}

const knownPrefixes = ['image_emoticon', 'image_emotion', 'shoubai_emoji', 'tsj_emoji', 'tb_emoji', 'emoji_', 'bai_emoji', 'new_emoticon', 'tieba_emoji', 'emotion_', 'emoticon_'];

const inlineEmojiTypes: number[] = [2, 6, 7, 9, 10, 11, 12, 13];

export function isInlineEmojiType(t: number): boolean {
  return inlineEmojiTypes.indexOf(t) >= 0;
}

function getSpacedEmojiId(text: string): string {
  const id = text.replace(/[[\]【】「」『』《》（）()<>{}]/g, '').trim();
  const m = id.match(/^#?\s*emot(?:ion|icon)\s*[:：]?\s*(\d+)$/);
  return m ? 'image_emoticon' + m[1] : '';
}

function stripHash(raw: string): string {
  const id = raw.replace(/[[\]【】「」『』《」（）()<>{}]/g, '').trim();
  const hashStripped = id.replace(/^#+/, '');
  if (/^\d+$/.test(hashStripped)) return hashStripped;
  return '';
}

export function resolveEmojiId(rawId: string): string {
  const id = rawId.replace(/[[\]【】「」『』《」（）()<>{}]/g, '').trim();
  if (!id) return '';
  const hashNum = stripHash(id);
  if (hashNum) return 'http://static.tieba.baidu.com/tb/editor/images/client/image_emoticon' + hashNum + '.png';
  if (/^\d+$/.test(id)) return 'http://static.tieba.baidu.com/tb/editor/images/client/image_emoticon' + id + '.png';
  const spaced = getSpacedEmojiId(id);
  if (spaced) return 'http://static.tieba.baidu.com/tb/editor/images/client/' + spaced + '.png';
  if (knownPrefixes.some(p => id.startsWith(p))) return 'http://static.tieba.baidu.com/tb/editor/images/client/' + id + '.png';
  const mapped = getEmojiIdFromMap(id);
  if (mapped) return 'http://static.tieba.baidu.com/tb/editor/images/client/' + mapped + '.png';
  const encoded = encodeURIComponent(id);
  return 'http://static.tieba.baidu.com/tb/editor/images/client/' + encoded + '.png';
}

export function isEmojiText(text: string): boolean {
  const id = text.replace(/[[\]【】「」『』《」（）()<>{}]/g, '').trim();
  if (!id) return false;
  if (stripHash(id)) return true;
  if (knownPrefixes.some(p => id.startsWith(p))) return true;
  if (/^\d+$/.test(id)) return true;
  if (getEmojiIdFromMap(id)) return true;
  if (getSpacedEmojiId(id)) return true;
  return false;
}

export function isValidEmojiId(rawId: string): boolean {
  const id = rawId.replace(/[[\]【】「」『』《」（）()<>{}]/g, '').trim();
  if (!id) return false;
  if (stripHash(id)) return true;
  if (knownPrefixes.some(p => id.startsWith(p))) return true;
  if (/^\d+$/.test(id)) return true;
  if (getEmojiIdFromMap(id)) return true;
  if (getSpacedEmojiId(id)) return true;
  return false;
}

export function richEditorToText(controller: RichEditorController): string {
  let out = '';
  try {
    const spans: RichEditorSpan[] = controller.getSpans();
    for (const s of spans) {
      const ts = s as RichEditorTextSpanResult;
      if (ts.value !== undefined && ts.value !== null && ts.value.length > 0) {
        out += ts.value;
        continue;
      }
      const img = s as RichEditorImageSpanResult;
      const url = String(img.valueResourceStr || '');
      const queryIdx = url.indexOf('?');
      const filename = queryIdx >= 0 ? url.substring(0, queryIdx) : url;
      let file = filename.substring(filename.lastIndexOf('/') + 1).replace(/\.(png|gif|jpg|jpeg|webp)$/i, '');
      const emoticonMatch = file.match(/^image_emoticon(\d+)$/);
      if (emoticonMatch) file = emoticonMatch[1];
      if (file) out += '#' + file;
    }
  } catch (_e) { }
  return out;
}

export function getEmojiUrlForItem(item: Dict): string {
  const directUrl = String(item.bsrc || item.src || item.icon || item.url || item.picUrl || item.thumbnail || item.c || '');
  if (directUrl.startsWith('http://') || directUrl.startsWith('https://') || directUrl.startsWith('//')) {
    if (directUrl.startsWith('https://')) return 'http://' + directUrl.substring(8);
    if (directUrl.startsWith('//')) return 'http:' + directUrl;
    return directUrl;
  }
  const textId = String(item.text || '').trim();
  const name = String(item.c || '').trim();
  if (textId && name && textId !== name) {
    registerEmoji(name, textId);
  }
  const rawId = String(item.id || item.text || item.c || '').trim();
  if (!rawId) return '';
  return resolveEmojiId(rawId);
}
