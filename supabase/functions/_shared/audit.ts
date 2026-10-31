import type { SupabaseClient } from "@supabase/supabase-js";
import { HttpError } from "./errors.ts";

export interface AuditEvent {
  actorId: string | null;
  action: string;
  targetType: string;
  targetId: string | null;
  metadata?: Record<string, unknown>;
}

const sensitiveKey = /(?:email|full.?name|phone|address|token|secret|password|raw|content|message|resume|video|url)/i;
function assertMinimizedMetadata(value: unknown, depth = 0): void {
  if (depth > 4) throw new HttpError("VALIDATION_FAILED", "Audit metadata is too deeply nested");
  if (value === null || typeof value === "boolean" || typeof value === "number") return;
  if (typeof value === "string") {
    if (value.length > 200 || /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i.test(value)) {
      throw new HttpError("VALIDATION_FAILED", "Audit metadata must not contain raw personal data");
    }
    return;
  }
  if (Array.isArray(value)) {
    if (value.length > 30) throw new HttpError("VALIDATION_FAILED", "Audit metadata list is too large");
    for (const item of value) assertMinimizedMetadata(item, depth + 1);
    return;
  }
  if (typeof value === "object") {
    for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
      if (sensitiveKey.test(key)) throw new HttpError("VALIDATION_FAILED", "Audit metadata contains a prohibited field");
      assertMinimizedMetadata(item, depth + 1);
    }
    return;
  }
  throw new HttpError("VALIDATION_FAILED", "Audit metadata is not JSON-safe");
}

/** Shared fail-closed audit writer. Callers pass identifiers/counts, never raw user content. */
export async function writeAuditEvent(client: SupabaseClient, event: AuditEvent): Promise<void> {
  if (!/^[a-z][a-z0-9_]{1,63}$/.test(event.action) || !/^[a-z][a-z0-9_]{1,63}$/.test(event.targetType)) {
    throw new HttpError("SERVICE_UNAVAILABLE", "Audit event is invalid");
  }
  const metadata = event.metadata ?? {};
  assertMinimizedMetadata(metadata);
  const { error } = await client.from("audit_log").insert({
    actor_id: event.actorId,
    action: event.action,
    target_type: event.targetType,
    target_id: event.targetId,
    metadata,
  });
  if (error) throw new HttpError("SERVICE_UNAVAILABLE", "Audit logging is unavailable");
}
