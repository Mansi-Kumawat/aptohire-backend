import { z } from "npm:zod@3.23.8";

const domainPattern = /^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/i;
const EmailSchema = z.string().trim().email().max(254).transform((value) => value.toLowerCase());
const DomainListSchema = z.array(z.string().trim().min(1).max(253).regex(domainPattern, "Enter valid email domains"))
  .max(20).transform((domains) => [...new Set(domains.map((domain) => domain.toLowerCase()))]);
const OptionalText = (max: number) => z.string().trim().max(max).optional();
// TODO(decision): the frozen contract does not specify contact-field bounds; retain conservative provisional limits until product confirms them.
const ContactName = z.string().trim().min(2).max(120);
const ContactRole = z.string().trim().min(2).max(80);
const ContactPhone = z.string().trim().min(3).max(40).optional();
const Message = OptionalText(1000);
const Honeypot = z.string().max(200);
const CaptchaToken = z.string().trim().min(1).max(4096).optional();

export const UniversityApplicationSchema = z.object({
  type: z.literal("university"),
  institution_name: z.string().trim().min(2).max(120),
  short_name: OptionalText(30),
  kind: z.enum(["university", "college", "school"]),
  tier: z.enum(["tier1", "tier2", "tier3", "other"]),
  // TODO(decision): the frozen contract gives no city/state/email-domain count bounds; provisional limits prevent oversized input.
  city: z.string().trim().min(1).max(100),
  state: z.string().trim().min(1).max(100),
  email_domains: DomainListSchema.optional(),
  student_count_band: z.enum(["<500", "500-2000", "2000-5000", "5000+"]),
  departments: OptionalText(200),
  contact_name: ContactName,
  contact_role: ContactRole,
  contact_email: EmailSchema,
  contact_phone: ContactPhone,
  message: Message,
  consent: z.literal(true),
  hp: Honeypot,
  captcha_token: CaptchaToken,
}).strict();

export const OrganizationApplicationSchema = z.object({
  type: z.literal("organization"),
  org_name: z.string().trim().min(2).max(120),
  org_kind: z.enum(["corporate", "startup", "agency", "other"]),
  size_band: z.enum(["1-10", "11-50", "51-250", "251-1000", "1000+"]),
  website: z.string().trim().url().max(2048).refine((value) => {
    try {
      const url = new URL(value);
      return url.protocol === "https:" && !url.username && !url.password;
    } catch {
      return false;
    }
  }, "Website must be an HTTPS URL without embedded credentials").transform((value) => new URL(value).toString()),
  hiring_focus: z.array(z.enum(["web_frontend", "backend", "data", "management_commerce", "other"])).min(1).max(5),
  contact_name: ContactName,
  contact_role: ContactRole,
  work_email: EmailSchema,
  message: Message,
  consent: z.literal(true),
  hp: Honeypot,
  captcha_token: CaptchaToken,
}).strict();

export const SubmitApplicationInputSchema = z.discriminatedUnion("type", [
  UniversityApplicationSchema,
  OrganizationApplicationSchema,
]);

export const SubmitApplicationOutputSchema = z.object({
  reference: z.string().regex(/^AH-[A-Z0-9]{6}$/),
  status: z.literal("received"),
}).strict();

export type SubmitApplicationInput = z.infer<typeof SubmitApplicationInputSchema>;
export type SubmitApplicationOutput = z.infer<typeof SubmitApplicationOutputSchema>;

const FREE_EMAIL_DOMAINS = new Set([
  "gmail.com", "gmail.test", "googlemail.com", "yahoo.com", "yahoo.co.in", "yahoo.co.uk", "yahoo.co.jp", "yahoo.fr", "yahoo.de", "yahoo.es", "yahoo.it", "yahoo.ca", "yahoo.com.au", "yahoo.test",
  "outlook.com", "outlook.co.in", "outlook.co.uk", "outlook.test", "hotmail.com", "hotmail.co.uk", "hotmail.fr", "hotmail.de", "hotmail.test", "live.com", "live.co.uk", "icloud.com", "icloud.co.uk", "icloud.test",
  "me.com", "aol.com", "proton.me", "protonmail.com", "protonmail.ch", "proton.test", "gmx.com", "gmx.net", "mail.com", "yandex.com", "yandex.ru", "yandex.com.tr",
  "zoho.com", "fastmail.com", "tutanota.com", "tuta.com", "hey.com", "yopmail.com", "icloud.com.au",
]);

export function isFreeOrganizationEmail(email: string): boolean {
  const domain = email.trim().toLowerCase().split("@").at(-1) ?? "";
  return FREE_EMAIL_DOMAINS.has(domain);
}

export function applicationBusinessPayload(input: SubmitApplicationInput): Record<string, unknown> {
  return Object.fromEntries(Object.entries(input).filter(([key]) => key !== "hp" && key !== "captcha_token"));
}
