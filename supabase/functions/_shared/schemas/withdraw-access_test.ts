import { assertEquals } from "jsr:@std/assert@1";
import { WithdrawAccessInputSchema, WithdrawAccessOutputSchema } from "./withdraw-access.ts";

Deno.test("withdraw-access accepts only a request id and returns withdrawn", () => {
  const request_id = "00000000-0000-4000-8000-000000000001";
  assertEquals(WithdrawAccessInputSchema.safeParse({ request_id }).success, true);
  assertEquals(WithdrawAccessInputSchema.safeParse({ request_id, student_id: request_id }).success, false);
  assertEquals(WithdrawAccessOutputSchema.safeParse({ status: "withdrawn" }).success, true);
});
