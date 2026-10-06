import image from '@ohos.multimedia.image';
import fs from '@ohos.file.fs';

export interface CompressImageResult {
  buffer: ArrayBuffer;
  width: number;
  height: number;
}

const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const MAX_IMAGE_SIDE = 1080;

function readAllBytes(fd: number, size: number): ArrayBuffer {
  const buf = new ArrayBuffer(size);
  let got = 0;
  while (got < size) {
    const n = fs.readSync(fd, buf, { offset: got, length: size - got });
    if (n <= 0) break;
    got += n;
  }
  return buf;
}

export async function compressImageToBuffer(uri: string): Promise<CompressImageResult> {
  const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
  const stat = fs.statSync(uri);
  let source: image.ImageSource | null = null;
  try {
    source = await image.createImageSource(file.fd);
    const info = await source.getImageInfo();
    const width = info.size.width;
    const height = info.size.height;
    const needScale = width > MAX_IMAGE_SIDE || height > MAX_IMAGE_SIDE || stat.size > MAX_IMAGE_BYTES;
    if (!needScale) {
      const buffer = readAllBytes(file.fd, stat.size);
      return { buffer: buffer, width: width, height: height };
    }
    const scale = Math.min(MAX_IMAGE_SIDE / width, MAX_IMAGE_SIDE / height, 1);
    const targetW = Math.max(1, Math.round(width * scale));
    const targetH = Math.max(1, Math.round(height * scale));
    const pm = await source.createPixelMap({
      desiredSize: { width: targetW, height: targetH },
      editable: true
    });
    const packer = image.createImagePacker();
    const packed = await packer.packing(pm, { format: 'image/jpeg', quality: 95 });
    await pm.release();
    if (packed.byteLength > MAX_IMAGE_BYTES) {
      throw new Error('图片压缩后仍超过大小限制');
    }
    return { buffer: packed, width: targetW, height: targetH };
  } finally {
    if (source) {
      try { await source.release(); } catch (e) {}
    }
    try { fs.closeSync(file); } catch (e) {}
  }
}
