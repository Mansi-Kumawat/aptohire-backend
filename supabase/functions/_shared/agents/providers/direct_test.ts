import { assertEquals } from "jsr:@std/assert@1";
import { z } from "npm:zod@3.23.8";
import { generateDirectJson, generateValidatedDirectJson, providerConfigFingerprint } from "./direct.ts";

Deno.test("provider fingerprint invalidates model changes without containing API keys", () => {
  const names = ["LLM_PROVIDER_ORDER", "LLM_MODEL_FAST", "LLM_MODEL_FAST_GEMINI", "GEMINI_API_KEY"];
  const saved = new Map(names.map((name) => [name, Deno.env.get(name)]));
  try {
    Deno.env.set("LLM_PROVIDER_ORDER", "gemini");
    Deno.env.set("LLM_MODEL_FAST_GEMINI", "fictional-model-a");
    Deno.env.set("GEMINI_API_KEY", "must-not-appear-in-fingerprint");
    const before = providerConfigFingerprint("fast");
    assertEquals(before.includes("must-not-appear-in-fingerprint"), false);
    Deno.env.set("GEMINI_API_KEY", "rotated-fictional-key");
    assertEquals(providerConfigFingerprint("fast"), before);
    Deno.env.set("LLM_MODEL_FAST_GEMINI", "fictional-model-b");
    assertEquals(providerConfigFingerprint("fast") === before, false);
  } finally {
    for (const [name, value] of saved) value === undefined ? Deno.env.delete(name) : Deno.env.set(name, value);
  }
});

Deno.test("direct JSON provider uses JSON mode, retries transient status, and falls back", async () => {
  const names = ["LLM_PROVIDER_ORDER", "GEMINI_API_KEY", "GROQ_API_KEY", "OPENROUTER_API_KEY", "LLM_MODEL_FAST"];
  const saved = new Map(names.map((name) => [name, Deno.env.get(name)]));
  try {
    Deno.env.set("LLM_PROVIDER_ORDER", "gemini,groq,openrouter");
    Deno.env.set("GEMINI_API_KEY", "fictional-gemini-key");
    Deno.env.set("GROQ_API_KEY", "fictional-groq-key");
    Deno.env.set("OPENROUTER_API_KEY", "fictional-openrouter-key");
    Deno.env.set("LLM_MODEL_FAST", "synthetic-fast-model");
    let geminiCalls = 0;
    let capCalls = 0;
    const geminiResult = await generateDirectJson({
      kind: "fast", system: "Return JSON.", user: "Synthetic input.",
      beforeProvider: (provider) => { capCalls++; assertEquals(provider, "gemini"); return Promise.resolve(true); },
      fetcher: (input, init) => {
        geminiCalls++;
        assertEquals(init?.redirect, "error");
        assertEquals(String(input).includes("synthetic-fast-model"), true);
        assertEquals(JSON.parse(String(init?.body)).generationConfig.responseMimeType, "application/json");
        return Promise.resolve(new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: JSON.stringify({ ok: true }) }] } }], usageMetadata: { promptTokenCount: 2, candidatesTokenCount: 3 } }), { status: 200 }));
      },
    });
    assertEquals(geminiCalls, 1);
    assertEquals(capCalls, 1);
    assertEquals(geminiResult.provider, "gemini");
    assertEquals(geminiResult.value, { ok: true });
    assertEquals(geminiResult.inputTokens, 2);

    Deno.env.set("LLM_PROVIDER_ORDER", "groq,openrouter");
    let groqCalls = 0;
    const fallbackResult = await generateDirectJson({
      kind: "fast", system: "Return JSON.", user: "Synthetic input.",
      fetcher: (input, init) => {
        const url = String(input);
        if (url.includes("api.groq.com")) {
          groqCalls++;
          assertEquals(JSON.parse(String(init?.body)).response_format.type, "json_object");
          return Promise.resolve(new Response("quota", { status: 429 }));
        }
        return Promise.resolve(new Response(JSON.stringify({ choices: [{ message: { content: JSON.stringify({ ok: true }) } }], usage: { prompt_tokens: 4, completion_tokens: 5 } }), { status: 200 }));
      },
    });
    assertEquals(groqCalls, 2);
    assertEquals(fallbackResult.provider, "openrouter");
    assertEquals(fallbackResult.outputTokens, 5);

    Deno.env.set("LLM_PROVIDER_ORDER", "gemini");
    let repairCalls = 0;
    const repaired = await generateValidatedDirectJson(z.object({ ok: z.boolean() }).strict(), {
      kind: "fast", system: "Return an object with ok.", user: "Synthetic input.",
      fetcher: () => {
        repairCalls++;
        const text = JSON.stringify(repairCalls === 1 ? { bad: true } : { ok: true });
        return Promise.resolve(new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text }] } }] }), { status: 200 }));
      },
    });
    assertEquals(repairCalls, 2);
    assertEquals(repaired.data, { ok: true });
  } finally {
    for (const [name, value] of saved) value === undefined ? Deno.env.delete(name) : Deno.env.set(name, value);
  }
});


Deno.test("multimodal requests attach bounded media to Gemini and never fall back to text-only providers", async () => {
  const names = ["LLM_PROVIDER_ORDER", "GEMINI_API_KEY", "GROQ_API_KEY", "OPENROUTER_API_KEY", "LLM_MODEL_FAST", "LLM_MODEL_FAST_GEMINI"];
  const saved = new Map(names.map((name) => [name, Deno.env.get(name)]));
  try {
    Deno.env.set("LLM_PROVIDER_ORDER", "groq,gemini,openrouter");
    Deno.env.set("GEMINI_API_KEY", "fictional-gemini-key");
    Deno.env.set("GROQ_API_KEY", "fictional-groq-key");
    Deno.env.set("OPENROUTER_API_KEY", "fictional-openrouter-key");
    Deno.env.set("LLM_MODEL_FAST_GEMINI", "synthetic-multimodal-model");
    let calls = 0;
    const result = await generateDirectJson({
      kind: "fast", system: "Return JSON.", user: "Analyze this synthetic media.",
      media: [{ mimeType: "video/mp4", bytes: new Uint8Array([1, 2, 3]) }],
      fetcher: (input, init) => {
        calls++;
        assertEquals(new URL(String(input)).hostname, "generativelanguage.googleapis.com");
        const request = JSON.parse(String(init?.body));
        assertEquals(request.contents[0].parts[1].inline_data, { mime_type: "video/mp4", data: "AQID" });
        return Promise.resolve(new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: JSON.stringify({ ok: true }) }] } }] }), { status: 200 }));
      },
    });
    assertEquals(calls, 1);
    assertEquals(result.provider, "gemini");
    assertEquals(result.value, { ok: true });
  } finally {
    for (const [name, value] of saved) value === undefined ? Deno.env.delete(name) : Deno.env.set(name, value);
  }
});

Deno.test("direct provider calls reject redirects and bound response bytes without exposing secrets", async () => {
  const names = ["LLM_PROVIDER_ORDER", "GEMINI_API_KEY", "LLM_MODEL_FAST"];
  const saved = new Map(names.map((name) => [name, Deno.env.get(name)]));
  try {
    Deno.env.set("LLM_PROVIDER_ORDER", "gemini");
    Deno.env.set("GEMINI_API_KEY", "synthetic-provider-key-do-not-leak");
    Deno.env.set("LLM_MODEL_FAST", "synthetic-fast-model");
    let redirectCalls = 0;
    let redirectError = "";
    try {
      await generateDirectJson({
        kind: "fast", system: "Return JSON.", user: "Synthetic data.",
        fetcher: (_input, init) => {
          redirectCalls++;
          assertEquals(init?.redirect, "error");
          return Promise.resolve(new Response("private redirect response", { status: 302, headers: { location: "https://attacker.example/collect" } }));
        },
      });
    } catch (error) { redirectError = String(error); }
    assertEquals(redirectError.includes("DIRECT_PROVIDERS_UNAVAILABLE"), true);
    assertEquals(redirectError.includes("synthetic-provider-key-do-not-leak"), false);
    assertEquals(redirectError.includes("private redirect response"), false);
    assertEquals(redirectCalls, 1);

    let oversizedCalls = 0;
    let oversizedError = "";
    try {
      await generateDirectJson({
        kind: "fast", system: "Return JSON.", user: "Synthetic data.",
        fetcher: () => {
          oversizedCalls++;
          return Promise.resolve(new Response("bounded response", { status: 200, headers: { "content-length": "1000001" } }));
        },
      });
    } catch (error) { oversizedError = String(error); }
    assertEquals(oversizedError.includes("DIRECT_PROVIDERS_UNAVAILABLE"), true);
    assertEquals(oversizedError.includes("synthetic-provider-key-do-not-leak"), false);
    assertEquals(oversizedError.includes("bounded response"), false);
    assertEquals(oversizedCalls, 2);
  } finally {
    for (const [name, value] of saved) value === undefined ? Deno.env.delete(name) : Deno.env.set(name, value);
  }
});
