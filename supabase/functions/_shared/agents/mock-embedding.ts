/** Deterministic, synthetic hash-derived embedding for mock/fallback matching only. */
export function mockEmbedding(text: string, dimensions = 768): number[] {
  if (!Number.isInteger(dimensions) || dimensions < 8 || dimensions > 4096) {
    throw new RangeError("Embedding dimension must be an integer between 8 and 4096");
  }
  const vector = new Array<number>(dimensions).fill(0);
  const tokens = text.normalize("NFKC").toLowerCase().match(/[\p{L}\p{N}_-]{2,}/gu) ?? [];
  for (const token of tokens) {
    let state = 0x811c9dc5;
    for (const character of token) {
      state ^= character.codePointAt(0)!;
      state = Math.imul(state, 0x01000193) >>> 0;
    }
    for (let i = 0; i < 8; i++) {
      state ^= state << 13;
      state ^= state >>> 17;
      state ^= state << 5;
      state >>>= 0;
      vector[state % dimensions] += (state & 1) === 0 ? 1 : -1;
    }
  }
  const norm = Math.sqrt(vector.reduce((sum, value) => sum + value * value, 0));
  return norm === 0 ? vector : vector.map((value) => value / norm);
}
