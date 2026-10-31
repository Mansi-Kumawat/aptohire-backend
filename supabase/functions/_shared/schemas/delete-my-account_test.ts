import { assertEquals } from "jsr:@std/assert@1";
import { DeleteMyAccountInputSchema, DeleteMyAccountOutputSchema } from "./delete-my-account.ts";

Deno.test("delete-my-account requires password and exact confirmation", () => {
  assertEquals(DeleteMyAccountInputSchema.safeParse({ password: "fictional-password", confirm: "DELETE" }).success, true);
  assertEquals(DeleteMyAccountInputSchema.safeParse({ password: "fictional-password", confirm: "delete" }).success, false);
  assertEquals(DeleteMyAccountInputSchema.safeParse({ password: "fictional-password", confirm: "DELETE", user_id: crypto.randomUUID() }).success, false);
  assertEquals(DeleteMyAccountInputSchema.safeParse({ confirm: "DELETE" }).success, false);
});

Deno.test("delete-my-account has an empty success response", () => {
  assertEquals(DeleteMyAccountOutputSchema.safeParse({}).success, true);
  assertEquals(DeleteMyAccountOutputSchema.safeParse({ user_id: crypto.randomUUID() }).success, false);
});
