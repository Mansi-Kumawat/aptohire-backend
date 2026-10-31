import { createClient, type SupabaseClient, type User } from "@supabase/supabase-js";
import { HttpError } from "./errors.ts";

export type AppRole = "student" | "university" | "organization" | "admin";
export interface AuthContext {
  user: User;
  role: AppRole;
  aal: string | null;
  client: SupabaseClient;
}

function decodeJwtPayload(token: string): Record<string, unknown> | null {
  try {
    const part = token.split(".")[1];
    if (!part) return null;
    const normalized = part.replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=")));
  } catch {
    return null;
  }
}

export async function authenticate(request: Request, options: { allowDeletionPending?: boolean } = {}): Promise<AuthContext> {
  const authorization = request.headers.get("authorization");
  const token = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) throw new HttpError("UNAUTHENTICATED", "Sign-in required");
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anonKey) throw new HttpError("SERVICE_UNAVAILABLE", "Authentication is unavailable");
  const client = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: authData, error: authError } = await client.auth.getUser(token);
  if (authError || !authData.user) throw new HttpError("UNAUTHENTICATED", "Invalid or expired session");
  const { data: profile, error: profileError } = await client.from("profiles").select("role,deletion_started_at").eq("id", authData.user.id).maybeSingle();
  if (profileError || !profile?.role) throw new HttpError("FORBIDDEN", "Account role is not configured");
  if (profile.deletion_started_at && !options.allowDeletionPending) throw new HttpError("FORBIDDEN", "Account deletion is in progress");
  const role = profile.role as AppRole;
  if (!["student", "university", "organization", "admin"].includes(role)) throw new HttpError("FORBIDDEN", "Account role is not allowed");
  const claims = decodeJwtPayload(token);
  return { user: authData.user, role, aal: typeof claims?.aal === "string" ? claims.aal : null, client };
}
