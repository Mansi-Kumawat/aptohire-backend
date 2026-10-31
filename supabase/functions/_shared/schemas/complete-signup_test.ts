import { assertEquals } from "jsr:@std/assert@1";
import { CompleteSignupInputSchema } from "./complete-signup.ts";

Deno.test("complete-signup accepts only supported portal and reference", () => {
  assertEquals(CompleteSignupInputSchema.safeParse({ portal: "student" }).success, true);
  assertEquals(CompleteSignupInputSchema.safeParse({ portal: "admin" }).success, false);
  assertEquals(CompleteSignupInputSchema.safeParse({ portal: "university", application_ref: "AH-7K2Q9F" }).success, true);
  assertEquals(CompleteSignupInputSchema.safeParse({ portal: "organization", unexpected: true }).success, false);
});
