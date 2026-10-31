export function constantTimeSecretEqual(expected: string, supplied: string): boolean {
  if (!expected || !supplied) return false;
  const left = new TextEncoder().encode(expected);
  const right = new TextEncoder().encode(supplied);
  let mismatch = left.length ^ right.length;
  for (let i = 0; i < Math.max(left.length, right.length); i++) mismatch |= (left[i] ?? 0) ^ (right[i] ?? 0);
  return mismatch === 0;
}
