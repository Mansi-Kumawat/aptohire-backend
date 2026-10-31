import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import { corsHeaders, preflight } from "../_shared/cors.ts";
import { hmacHex } from "../_shared/hash.ts";
import { requestClientIp } from "../_shared/request-ip.ts";
import { buildPublicCredentialResponse } from "../_shared/public-credential.ts";

const genericNotFound = (headers: Headers) => {
  const responseHeaders = new Headers(headers);
  responseHeaders.set("Cache-Control", "public, max-age=30, s-maxage=60");
  return Response.json({ error: { code: "NOT_FOUND", message: "Credential not found" } }, { status: 404, headers: responseHeaders });
};

Deno.serve(async (request: Request): Promise<Response> => {
  const options = preflight(request);
  if (options) return options;
  const headers = corsHeaders(request);
  if (request.method !== "GET") return Response.json({ error: { code: "VALIDATION_FAILED", message: "GET required" } }, { status: 405, headers });
  const id = new URL(request.url).searchParams.get("id") ?? "";
  try {
    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const pepper = Deno.env.get("RATE_LIMIT_PEPPER");
    if (!url || !serviceKey || !pepper) throw new Error("server configuration missing");
    const ip = requestClientIp(request);
    if (!ip) throw new Error("trusted client IP unavailable");
    const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const ipHash = await hmacHex(pepper, `public-verify:ip:${ip}`);
    const { data: limitRows, error: limitError } = await admin.rpc("consume_rate_limit", { p_bucket: "public-verify", p_key_hash: ipHash, p_max: 60, p_window_seconds: 60 });
    if (limitError || !limitRows?.[0]) throw new Error("rate limiter unavailable");
    if (!limitRows[0].allowed) return Response.json({ error: { code: "RATE_LIMITED", message: "Too many requests" } }, { status: 429, headers: { ...Object.fromEntries(headers), "Retry-After": String(limitRows[0].retry_after) } });
    if (!/^[a-f0-9]{18}$/.test(id)) return genericNotFound(headers);

    const { data: student, error: studentError } = await admin.from("students").select("id,full_name,credential_id,visibility,created_at,updated_at").eq("credential_id", id).maybeSingle();
    if (studentError) throw new Error("credential lookup failed");
    if (!student) return genericNotFound(headers);
    const sharedFields = Array.isArray(student.visibility?.public_verify) ? student.visibility.public_verify : [];
    const scoresQuery = await admin.from("skill_scores").select("score,level,verified,share_ok,pending_review,updated_at,skills(name)")
      .eq("student_id", student.id).eq("verified", true).eq("share_ok", true).eq("pending_review", false);
    if (scoresQuery.error) throw new Error("credential lookup failed");
    const scoreRows = (scoresQuery.data ?? []).map((row) => ({
      ...row,
      name: (row.skills as { name?: string } | null)?.name ?? "",
    }));
    let affiliation: { label: string; verification: "roster" | "student_id" | "unverified" } | undefined;
    if (sharedFields.includes("university")) {
      const { data, error } = await admin.from("affiliations").select("verification,universities(name,short_name),university_name_text").eq("student_id", student.id).eq("is_current", true).maybeSingle();
      if (error) throw new Error("credential affiliation lookup failed");
      if (data) {
        const uni = data.universities as { name?: string; short_name?: string } | null;
        affiliation = { label: uni?.short_name || uni?.name || data.university_name_text || "University", verification: data.verification };
      }
    }
    const response = buildPublicCredentialResponse({
      credentialId: student.credential_id,
      fullName: student.full_name,
      createdAt: student.created_at,
      updatedAt: student.updated_at,
      sharedFields,
      skills: scoreRows,
      ...(affiliation ? { affiliation } : {}),
    });
    const successHeaders = new Headers(headers);
    successHeaders.set("Cache-Control", "public, max-age=30, s-maxage=60");
    return Response.json(response, { status: 200, headers: successHeaders });
  } catch {
    // Keep operational errors free of credential, IP, and key material.
    return Response.json({ error: { code: "SERVICE_UNAVAILABLE", message: "Verification is temporarily unavailable" } }, { status: 503, headers });
  }
});
