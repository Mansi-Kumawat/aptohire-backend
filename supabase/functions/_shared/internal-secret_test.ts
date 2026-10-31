import { assertEquals } from "jsr:@std/assert@1";
import { constantTimeSecretEqual } from "./internal-secret.ts";

Deno.test("internal secret comparison accepts only exact secrets", () => {
  assertEquals(constantTimeSecretEqual("fictional-cleanup-secret", "fictional-cleanup-secret"), true);
  assertEquals(constantTimeSecretEqual("fictional-cleanup-secret", "fictional-cleanup-secreu"), false);
  assertEquals(constantTimeSecretEqual("fictional-cleanup-secret", "fictional-cleanup-secret-extra"), false);
  assertEquals(constantTimeSecretEqual("fictional-cleanup-secret", ""), false);
  assertEquals(constantTimeSecretEqual("", ""), false);
});
