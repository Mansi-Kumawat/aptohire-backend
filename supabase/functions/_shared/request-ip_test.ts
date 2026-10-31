import { assertEquals } from "jsr:@std/assert@1";
import { requestClientIp } from "./request-ip.ts";

Deno.test("client IP prefers the Cloudflare gateway header over other forwarded values", () => {
  const request = new Request("https://edge.example.test", { headers: {
    "cf-connecting-ip": "203.0.113.10",
    "x-real-ip": "198.51.100.20",
    "x-forwarded-for": "192.0.2.30, 10.0.0.1",
  } });
  assertEquals(requestClientIp(request), "203.0.113.10");
});

Deno.test("client IP falls back only to a syntactically valid address", () => {
  const request = new Request("https://edge.example.test", { headers: {
    "cf-connecting-ip": "attacker.example",
    "x-real-ip": "198.51.100.22",
    "x-forwarded-for": "192.0.2.30",
  } });
  assertEquals(requestClientIp(request), "198.51.100.22");
  assertEquals(requestClientIp(new Request("https://edge.example.test", { headers: { "x-forwarded-for": "bad-value" } })), undefined);
});
