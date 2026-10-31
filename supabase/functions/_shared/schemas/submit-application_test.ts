import { assertEquals } from "jsr:@std/assert@1";
import {
  applicationBusinessPayload,
  isFreeOrganizationEmail,
  SubmitApplicationInputSchema,
  SubmitApplicationOutputSchema,
} from "./submit-application.ts";

const university = {
  type: "university",
  institution_name: "Fictional Test University",
  kind: "university",
  tier: "tier2",
  city: "Jaipur",
  state: "Rajasthan",
  email_domains: [" UNI-A.EDU.TEST "],
  student_count_band: "500-2000",
  contact_name: "Fictional Contact",
  contact_role: "TPO",
  contact_email: "TPO@UNI-A.EDU.TEST",
  consent: true,
  hp: "",
};

Deno.test("submit-application accepts and normalizes the frozen university contract", () => {
  const parsed = SubmitApplicationInputSchema.safeParse(university);
  assertEquals(parsed.success, true);
  if (parsed.success && parsed.data.type === "university") {
    assertEquals(parsed.data.contact_email, "tpo@uni-a.edu.test");
    assertEquals(parsed.data.email_domains, ["uni-a.edu.test"]);
  }
});

Deno.test("submit-application accepts the frozen organization union and HTTPS website only", () => {
  const organization = {
    type: "organization",
    org_name: "Fictional Hiring Company",
    org_kind: "startup",
    size_band: "11-50",
    website: "https://company.example.test/",
    hiring_focus: ["web_frontend", "data"],
    contact_name: "Fictional Contact",
    contact_role: "Recruiter",
    work_email: "talent@company.example.test",
    consent: true,
    hp: "",
  };
  assertEquals(SubmitApplicationInputSchema.safeParse(organization).success, true);
  assertEquals(SubmitApplicationInputSchema.safeParse({ ...organization, website: "http://company.example.test" }).success, false);
  assertEquals(SubmitApplicationInputSchema.safeParse({ ...organization, unknown: true }).success, false);
});

Deno.test("honeypot and captcha are excluded from stored business payload", () => {
  const parsed = SubmitApplicationInputSchema.parse({ ...university, hp: "", captcha_token: "synthetic-token" });
  const payload = applicationBusinessPayload(parsed);
  assertEquals("hp" in payload, false);
  assertEquals("captcha_token" in payload, false);
  assertEquals("consent" in payload, true);
});

Deno.test("free-mail check covers common public providers and reserved test fixtures", () => {
  assertEquals(isFreeOrganizationEmail("person@gmail.com"), true);
  assertEquals(isFreeOrganizationEmail("person@gmail.test"), true);
  assertEquals(isFreeOrganizationEmail("person@yahoo.fr"), true);
  assertEquals(isFreeOrganizationEmail("person@outlook.co.in"), true);
  assertEquals(isFreeOrganizationEmail("person@protonmail.ch"), true);
  assertEquals(isFreeOrganizationEmail("person@company.example.test"), false);
});

Deno.test("response shape is strict and uses the frozen receipt", () => {
  assertEquals(SubmitApplicationOutputSchema.safeParse({ reference: "AH-7K2Q9F", status: "received" }).success, true);
  assertEquals(SubmitApplicationOutputSchema.safeParse({ reference: "AH-7K2Q9F", status: "approved" }).success, false);
  assertEquals(SubmitApplicationOutputSchema.safeParse({ reference: "AH-7K2Q9F", status: "received", id: "x" }).success, false);
});
