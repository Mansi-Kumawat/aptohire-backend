import type { SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";
import { HttpError } from "./errors.ts";

export type AppConfig = ReadonlyMap<string, unknown>;

/** Load only requested server-side app_config keys; missing/error state fails closed. */
export async function loadAppConfig(client: SupabaseClient, keys: readonly string[]): Promise<AppConfig> {
  const uniqueKeys = [...new Set(keys)];
  if (!uniqueKeys.length || uniqueKeys.some((key) => !/^[A-Z][A-Z0-9_]{0,63}$/.test(key))) {
    throw new HttpError("SERVICE_UNAVAILABLE", "Application settings are unavailable");
  }
  const { data, error } = await client.from("app_config").select("key,value").in("key", uniqueKeys);
  if (error || !Array.isArray(data)) throw new HttpError("SERVICE_UNAVAILABLE", "Application settings are unavailable");
  return new Map(data.map((row: { key: string; value: unknown }) => [row.key, row.value]));
}

export function configString(config: AppConfig, key: string, fallback: string): string {
  const value = config.get(key);
  return typeof value === "string" ? value : fallback;
}

export function configBoolean(config: AppConfig, key: string, fallback: boolean): boolean {
  const value = config.get(key);
  return typeof value === "boolean" ? value : fallback;
}

export function configNumber(config: AppConfig, key: string, fallback: number): number {
  const raw = config.get(key);
  const value = typeof raw === "number" ? raw : typeof raw === "string" ? Number(raw) : NaN;
  return Number.isFinite(value) ? value : fallback;
}
