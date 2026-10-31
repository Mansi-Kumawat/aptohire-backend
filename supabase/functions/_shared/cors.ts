const localOrigins = new Set(["http://localhost:5173", "http://localhost:5174", "http://localhost:5175", "http://localhost:5176", "http://localhost:5177"]);

export function corsHeaders(request: Request): Headers {
  const origin = request.headers.get("origin");
  const configured = (Deno.env.get("ALLOWED_ORIGINS") ?? "").split(",").map((v) => v.trim()).filter(Boolean);
  const allowed = new Set([...localOrigins, ...configured]);
  const headers = new Headers({ "Vary": "Origin", "Access-Control-Allow-Methods": "GET,POST,OPTIONS", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, idempotency-key" });
  if (origin && allowed.has(origin)) headers.set("Access-Control-Allow-Origin", origin);
  return headers;
}

export function preflight(request: Request): Response | null {
  if (request.method !== "OPTIONS") return null;
  return new Response(null, { status: 204, headers: corsHeaders(request) });
}
