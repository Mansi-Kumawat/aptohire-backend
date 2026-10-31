const emailPattern = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i;
const urlPattern = /(?:https?:\/\/|www\.)\S+|\b(?:[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?\.)+(?:[A-Z]{2,}|xn--[A-Z0-9-]{2,})(?:\/[^\s]*)?/i;
const handlePattern = /(?<![\p{L}\p{N}])@[\p{L}\p{N}_.-]{2,}/iu;
const phonePattern = /(?:\+?\d[\d().\s-]{6,}\d)/g;

export function containsContactDetails(value: string): boolean {
  const normalized = value.normalize("NFKC").replace(/[\u200B-\u200F\uFEFF]/g, "");
  if (emailPattern.test(normalized) || urlPattern.test(normalized) || handlePattern.test(normalized)) return true;
  const possiblePhones = normalized.match(phonePattern) ?? [];
  return possiblePhones.some((match) => (match.match(/\d/g)?.length ?? 0) >= 8);
}
