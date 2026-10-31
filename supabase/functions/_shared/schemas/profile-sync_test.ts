import { assertEquals, assertFalse } from "@std/assert";
import { ProfileSyncInputSchema, ProfileSyncOutputSchema } from "./profile-sync.ts";

Deno.test("profile-sync accepts only documented strict action payloads", () => {
  assertEquals(ProfileSyncInputSchema.safeParse({ action: "github_start" }).success, true);
  assertEquals(ProfileSyncInputSchema.safeParse({ action: "github_sync", source_id: "00000000-0000-4000-8000-000000000001" }).success, true);
  assertFalse(ProfileSyncInputSchema.safeParse({ action: "github_start", user_id: "spoofed" }).success);
  assertFalse(ProfileSyncInputSchema.safeParse({ action: "revoke", source_id: "bad" }).success);
  assertFalse(ProfileSyncInputSchema.safeParse({ action: "linkedin_parse", text: "a", file_path: "b" }).success);
  assertFalse(ProfileSyncInputSchema.safeParse({ action: "linkedin_parse", text: "x".repeat(20_001) }).success);
});

Deno.test("profile-sync output validates frozen callback and proposal shapes", () => {
  assertEquals(ProfileSyncOutputSchema.safeParse({ authorize_url: "https://github.com/login/oauth/authorize" }).success, true);
  assertEquals(ProfileSyncOutputSchema.safeParse({ last_synced_at: new Date().toISOString(), proposals: [] }).success, true);
  assertFalse(ProfileSyncOutputSchema.safeParse({ authorize_url: "javascript:alert(1)" }).success);
});
