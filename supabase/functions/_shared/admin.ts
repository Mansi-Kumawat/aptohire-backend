import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";

export function createAdminClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) throw new Error("admin client configuration missing");
  return createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
}
