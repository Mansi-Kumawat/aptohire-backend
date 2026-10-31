const MAX_SAFE_UINT64 = BigInt(Number.MAX_SAFE_INTEGER);

function readUint32(bytes: Uint8Array, offset: number): number {
  return new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength).getUint32(offset, false);
}

function readUint64(bytes: Uint8Array, offset: number): number | null {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const value = (BigInt(view.getUint32(offset, false)) << 32n) | BigInt(view.getUint32(offset + 4, false));
  return value <= MAX_SAFE_UINT64 ? Number(value) : null;
}

function readAscii(bytes: Uint8Array, offset: number, length: number): string {
  return String.fromCharCode(...bytes.subarray(offset, offset + length));
}

function parseMovieHeaderDuration(bytes: Uint8Array, start: number, end: number): number | null {
  if (end - start < 20) return null;
  const version = bytes[start];
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  let timescale: number;
  let duration: number | null;
  if (version === 0) {
    if (end - start < 20) return null;
    timescale = view.getUint32(start + 12, false);
    duration = view.getUint32(start + 16, false);
  } else if (version === 1) {
    if (end - start < 32) return null;
    timescale = view.getUint32(start + 20, false);
    duration = readUint64(bytes, start + 24);
  } else return null;
  if (!timescale || duration === null || duration === 0 || duration === 0xffff_ffff || duration === Number.MAX_SAFE_INTEGER) return null;
  const seconds = duration / timescale;
  return Number.isFinite(seconds) && seconds > 0 ? seconds : null;
}

function parseIsoBmffDuration(bytes: Uint8Array): number | null {
  const visit = (start: number, end: number, depth: number): number | null => {
    if (depth > 8) return null;
    let offset = start;
    while (offset + 8 <= end) {
      const size32 = readUint32(bytes, offset);
      const type = readAscii(bytes, offset + 4, 4);
      let headerSize = 8;
      let boxSize = size32;
      if (size32 === 1) {
        if (offset + 16 > end) return null;
        const extended = readUint64(bytes, offset + 8);
        if (extended === null) return null;
        boxSize = extended;
        headerSize = 16;
      } else if (size32 === 0) boxSize = end - offset;
      if (boxSize < headerSize || boxSize > end - offset) return null;
      const payloadStart = offset + headerSize;
      const boxEnd = offset + boxSize;
      if (type === "mvhd") {
        const duration = parseMovieHeaderDuration(bytes, payloadStart, boxEnd);
        if (duration !== null) return duration;
      } else if (type === "moov") {
        const duration = visit(payloadStart, boxEnd, depth + 1);
        if (duration !== null) return duration;
      }
      if (boxSize === 0) return null;
      offset = boxEnd;
    }
    return null;
  };
  return visit(0, bytes.byteLength, 0);
}

type EbmlVint = { value: number; length: number; unknown: boolean };
function readEbmlVint(bytes: Uint8Array, offset: number, isSize: boolean): EbmlVint | null {
  if (offset >= bytes.length) return null;
  const first = bytes[offset];
  let mask = 0x80;
  let length = 1;
  while (length <= 8 && (first & mask) === 0) { mask >>= 1; length++; }
  if (length > 8 || offset + length > bytes.length) return null;
  const unknown = isSize && (first & (mask - 1)) === mask - 1 &&
    Array.from(bytes.subarray(offset + 1, offset + length)).every((byte) => byte === 0xff);
  if (unknown) return { value: 0, length, unknown: true };
  let value = isSize ? first & (mask - 1) : first;
  for (let index = 1; index < length; index++) value = value * 256 + bytes[offset + index];
  if (!Number.isSafeInteger(value)) return null;
  return { value, length, unknown: false };
}

function parseWebmDuration(bytes: Uint8Array): number | null {
  // EBML element IDs: Segment=0x18538067, Info=0x1549A966,
  // TimestampScale=0x2AD7B1 (ns/tick), Duration=0x4489 (float).
  let offset = 0;
  const element = (at: number): { id: number; dataStart: number; end: number } | null => {
    const id = readEbmlVint(bytes, at, false);
    if (!id) return null;
    const size = readEbmlVint(bytes, at + id.length, true);
    if (!size) return null;
    const dataStart = at + id.length + size.length;
    const end = size.unknown ? bytes.length : dataStart + size.value;
    if (end < dataStart || end > bytes.length) return null;
    return { id: id.value, dataStart, end };
  };
  let segment: { dataStart: number; end: number } | null = null;
  while (offset < bytes.length) {
    const current = element(offset);
    if (!current) return null;
    if (current.id === 0x18538067) { segment = current; break; }
    if (current.end <= offset) return null;
    offset = current.end;
  }
  if (!segment) return null;
  let scale = 1_000_000;
  let durationTicks: number | null = null;
  offset = segment.dataStart;
  while (offset < segment.end) {
    const current = element(offset);
    if (!current) return null;
    if (current.id === 0x1549a966) {
      let infoOffset = current.dataStart;
      while (infoOffset < current.end) {
        const item = element(infoOffset);
        if (!item) return null;
        const width = item.end - item.dataStart;
        if (item.id === 0x2ad7b1 && width >= 1 && width <= 6) {
          let value = 0;
          for (let index = item.dataStart; index < item.end; index++) value = value * 256 + bytes[index];
          if (Number.isSafeInteger(value) && value > 0) scale = value;
        } else if (item.id === 0x4489 && (width === 4 || width === 8)) {
          const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
          durationTicks = width === 4 ? view.getFloat32(item.dataStart, false) : view.getFloat64(item.dataStart, false);
        }
        if (item.end <= infoOffset) return null;
        infoOffset = item.end;
      }
      if (durationTicks !== null) break;
    }
    if (current.end <= offset) return null;
    offset = current.end;
  }
  if (durationTicks === null || !Number.isFinite(durationTicks) || durationTicks <= 0) return null;
  const seconds = durationTicks * scale / 1_000_000_000;
  return Number.isFinite(seconds) && seconds > 0 ? seconds : null;
}

/** Parse container duration from bounded MP4/MOV or WebM bytes; malformed or unknown metadata fails closed. */
export function parseVideoDurationSeconds(bytes: Uint8Array, mimeType: string): number | null {
  if (bytes.byteLength < 16) return null;
  const normalized = mimeType.toLowerCase().split(";")[0].trim();
  if (normalized === "video/mp4" || normalized === "video/quicktime") return parseIsoBmffDuration(bytes);
  if (normalized === "video/webm") return parseWebmDuration(bytes);
  return null;
}
