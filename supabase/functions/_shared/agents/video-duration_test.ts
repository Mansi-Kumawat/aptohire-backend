import { assertEquals } from "@std/assert";
import { parseVideoDurationSeconds } from "./video-duration.ts";

function concat(...parts: Uint8Array[]): Uint8Array {
  const output = new Uint8Array(parts.reduce((sum, part) => sum + part.length, 0));
  let offset = 0;
  for (const part of parts) { output.set(part, offset); offset += part.length; }
  return output;
}

function box(type: string, payload: Uint8Array): Uint8Array {
  const result = new Uint8Array(8 + payload.length);
  new DataView(result.buffer).setUint32(0, result.length, false);
  for (let index = 0; index < 4; index++) result[4 + index] = type.charCodeAt(index);
  result.set(payload, 8);
  return result;
}

function ebmlElement(id: number[], payload: Uint8Array): Uint8Array {
  if (payload.length >= 127) throw new Error("fixture element too large");
  return concat(new Uint8Array(id), new Uint8Array([0x80 | payload.length]), payload);
}

Deno.test("MP4/MOV duration parser reads version-zero movie headers", () => {
  const mvhd = new Uint8Array(20);
  const view = new DataView(mvhd.buffer);
  view.setUint32(12, 1000, false);
  view.setUint32(16, 183000, false);
  const bytes = box("moov", box("mvhd", mvhd));
  assertEquals(parseVideoDurationSeconds(bytes, "video/mp4"), 183);
  assertEquals(parseVideoDurationSeconds(bytes, "video/quicktime"), 183);

  const versionOne = new Uint8Array(32);
  versionOne[0] = 1;
  const extendedView = new DataView(versionOne.buffer);
  extendedView.setUint32(20, 1000, false);
  extendedView.setUint32(24, 0, false);
  extendedView.setUint32(28, 183000, false);
  assertEquals(parseVideoDurationSeconds(box("moov", box("mvhd", versionOne)), "video/mp4"), 183);
});

Deno.test("WebM parser handles unknown-size Segment and reads scale plus float duration", () => {
  const scale = ebmlElement([0x2a, 0xd7, 0xb1], new Uint8Array([0x0f, 0x42, 0x40]));
  const floatBytes = new Uint8Array(4);
  new DataView(floatBytes.buffer).setFloat32(0, 2500, false);
  const duration = ebmlElement([0x44, 0x89], floatBytes);
  const info = ebmlElement([0x15, 0x49, 0xa9, 0x66], concat(scale, duration));
  const segment = concat(new Uint8Array([0x18, 0x53, 0x80, 0x67, 0x01, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]), info);
  assertEquals(parseVideoDurationSeconds(segment, "video/webm"), 2.5);
});

Deno.test("duration parser fails closed for malformed, unknown, unsupported, or zero duration", () => {
  assertEquals(parseVideoDurationSeconds(new Uint8Array(32), "video/mp4"), null);
  assertEquals(parseVideoDurationSeconds(new Uint8Array(32), "video/avi"), null);
  assertEquals(parseVideoDurationSeconds(box("moov", box("mvhd", new Uint8Array(20))), "video/mp4"), null);
  assertEquals(parseVideoDurationSeconds(new Uint8Array(5), "video/webm"), null);
});
