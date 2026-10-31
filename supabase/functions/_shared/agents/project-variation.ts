import { hmacHex } from "../hash.ts";
import type { AssignmentTemplate } from "./project-assignment.ts";

const SLOT_KEYS = ["domain", "dataset", "constraint", "twist"] as const;
type SlotKey = typeof SLOT_KEYS[number];
export type ProjectVariation = { template: AssignmentTemplate; fingerprint: string | null; values: Partial<Record<SlotKey, string>> };

function stableIndex(seed: string, key: string, attempt: number, size: number): number {
  let hash = 2166136261;
  for (const character of `${seed}:${key}:${attempt}`) hash = Math.imul(hash ^ character.charCodeAt(0), 16777619) >>> 0;
  return hash % size;
}

function record(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : null;
}

function extractOptions(value: unknown): Map<SlotKey, string[]> {
  const source = record(value);
  const slots = record(source?.variation_slots);
  const output = new Map<SlotKey, string[]>();
  for (const key of SLOT_KEYS) {
    const items = slots?.[key];
    if (!Array.isArray(items)) continue;
    const values = items.filter((item): item is string => typeof item === "string")
      .map((item) => item.trim().slice(0, 160)).filter(Boolean).slice(0, 16);
    if (values.length) output.set(key, values);
  }
  return output;
}

function containsPlaceholder(value: unknown, key: SlotKey): boolean {
  if (typeof value === "string") return value.includes(`{{${key}}}`);
  if (Array.isArray(value)) return value.some((item) => containsPlaceholder(item, key));
  const object = record(value);
  return object ? Object.values(object).some((item) => containsPlaceholder(item, key)) : false;
}

function replacePlaceholders(value: unknown, selected: Partial<Record<SlotKey, string>>): unknown {
  if (typeof value === "string") {
    return SLOT_KEYS.reduce((text, key) => selected[key] ? text.replaceAll(`{{${key}}}`, selected[key]!) : text, value);
  }
  if (Array.isArray(value)) return value.map((item) => replacePlaceholders(item, selected));
  const object = record(value);
  if (!object) return value;
  return Object.fromEntries(Object.entries(object)
    .filter(([key]) => key !== "variation_slots")
    .map(([key, item]) => [key, replacePlaceholders(item, selected)]));
}

/** Picks seeded template variations while spreading exact slot combinations across the demo cohort. */
export async function chooseProjectVariation(
  template: AssignmentTemplate,
  seed: string,
  hmacSecret: string,
  recentFingerprintCounts: ReadonlyMap<string, number>,
  maxUsesPerFingerprint = 3,
  maxAttempts = 16,
): Promise<ProjectVariation> {
  const options = extractOptions(template.brief);
  const keys = [...options.keys()].filter((key) => containsPlaceholder(template.brief, key));
  if (!keys.length) return { template, fingerprint: null, values: {} };
  if (hmacSecret.length < 32) throw new Error("Variation fingerprint secret must be at least 32 characters");
  if (!Number.isInteger(maxUsesPerFingerprint) || maxUsesPerFingerprint < 1 || !Number.isInteger(maxAttempts) || maxAttempts < 1 || maxAttempts > 64) {
    throw new RangeError("Variation limits are invalid");
  }

  let best: { values: Partial<Record<SlotKey, string>>; fingerprint: string; count: number } | null = null;
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const values: Partial<Record<SlotKey, string>> = {};
    for (const key of keys) {
      const choices = options.get(key)!;
      values[key] = choices[stableIndex(seed, key, attempt, choices.length)];
    }
    const canonical = keys.sort().map((key) => `${key}=${values[key]}`).join("&");
    const fingerprint = await hmacHex(hmacSecret, `project-variation:v1:${template.id}:${canonical}`);
    const count = recentFingerprintCounts.get(fingerprint) ?? 0;
    if (!best || count < best.count) best = { values, fingerprint, count };
    if (count < maxUsesPerFingerprint) {
      best = { values, fingerprint, count };
      break;
    }
  }
  if (!best) return { template, fingerprint: null, values: {} };
  const brief = replacePlaceholders(template.brief, best.values);
  const title = typeof template.title === "string" ? String(replacePlaceholders(template.title, best.values)) : template.title;
  return {
    template: { ...template, title, brief },
    fingerprint: best.fingerprint,
    values: best.values,
  };
}
