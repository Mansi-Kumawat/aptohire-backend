import { assertEquals, assertFalse } from "jsr:@std/assert@1";
import { AdminDecideTicketInputSchema, AdminDecideTicketOutputSchema } from "./admin-decide-ticket.ts";

const ticketId = "af000000-0000-4000-8000-000000000001";
const skillId = "af000000-0000-4000-8000-000000000002";
Deno.test("ticket action schema supports ack, assignment, and all decisions", () => {
  assertEquals(AdminDecideTicketInputSchema.safeParse({ action: "ack", ticket_id: ticketId }).success, true);
  assertEquals(AdminDecideTicketInputSchema.safeParse({ action: "assign", ticket_id: ticketId, assigned_to: skillId }).success, true);
  assertEquals(AdminDecideTicketInputSchema.safeParse({ action: "decide", ticket_id: ticketId, decision: "upheld" }).success, true);
  assertEquals(AdminDecideTicketInputSchema.safeParse({ action: "decide", ticket_id: ticketId, decision: "adjusted", adjusted_scores: [{ skill_id: skillId, score: 75 }], criterion: "testing", note: "Appeal review completed." }).success, true);
  assertEquals(AdminDecideTicketOutputSchema.safeParse({ ticket_id: ticketId, status: "closed", decision: "upheld" }).success, true);
});
Deno.test("ticket action schema rejects invalid decisions, assignments, and score payloads", () => {
  assertFalse(AdminDecideTicketInputSchema.safeParse({ action: "assign", ticket_id: ticketId }).success);
  assertFalse(AdminDecideTicketInputSchema.safeParse({ action: "decide", ticket_id: ticketId, decision: "adjusted" }).success);
  assertFalse(AdminDecideTicketInputSchema.safeParse({ action: "decide", ticket_id: ticketId, decision: "upheld", adjusted_scores: [{ skill_id: skillId, score: 75 }] }).success);
  assertFalse(AdminDecideTicketInputSchema.safeParse({ action: "decide", ticket_id: ticketId, decision: "adjusted", adjusted_scores: [{ skill_id: skillId, score: 75 }, { skill_id: skillId, score: 80 }] }).success);
  assertFalse(AdminDecideTicketInputSchema.safeParse({ action: "decide", ticket_id: ticketId, decision: "overturned", criterion: "https://example.test" }).success);
});
