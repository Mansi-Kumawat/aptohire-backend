# AptoHire — Product Requirements Document (Prototype / Demo)

> **Status:** Draft v0.1 · **Date:** 13 Oct 2026 · **Scope:** Prototype / demo web app (not production)
> **Companion docs:** [features.md](./features.md) · [architecture.md](./architecture.md) · [design.md](./design.md) · [agent.md](./agent.md)

---

## 1. One-liner

**AptoHire is an AI-driven skill-verification and hiring platform. Students prove what they can do through real projects; AI audits the work and issues a verified skill scorecard; organizations discover verified, anonymized talent and hire with the student's consent.**

Tagline options: *"Hired for what you can do."* · *"Proof over resumes."*

## 2. Problem

Traditional resumes cannot verify real skill or experience. Skilled students from Tier-2 and Tier-3 colleges are overlooked, and employers fall back on unreliable credentials and slow manual verification.

## 3. Solution

An AI-first credentialing and skill-verification platform that:

1. **Authenticates capability automatically** — an AI audit engine reviews a student's project (video + audio + code/docs) the way a human reviewer would.
2. **Manages the profile seamlessly** — one permanent profile that follows the student across university changes, graduation, dropout, and further study, with no double entry.
3. **Connects verified talent to jobs** — blind, consent-first predictive matching between verified students and organizations.

The result is a **digital resume backed by proof** that helps organizations hire talented students at low cost.

## 4. Prototype goals

The goal is a **convincing, end-to-end demo** that a university, an organization, or a judge can click through in 5–7 minutes, built on **free-tier infrastructure**.

| # | Goal | Done when |
|---|------|-----------|
| G1 | Show the **student magic moment** | A student submits a project and sees an evidence-linked scorecard + verified badge in under ~10 min (target < 2 min in demo mode) |
| G2 | Show **blind, consent-first matching** | An organization posts a job, sees anonymized ranked candidates with "why they match", requests access; the student accepts; identity is revealed only then |
| G3 | Show **university value** | A TPO dashboard with roster, verification status, skills and placement analytics |
| G4 | Show the **no double-entry lifecycle** | Seeded students move through alumni / dropout / masters across registered and unregistered universities without losing scores |
| G5 | Show **portal separation** | `aptohire.com` + `student.` / `university.` / `organization.` (+ `admin.`) subdomains from a single codebase |
| G6 | Run at **zero or near-zero cost** | Entire demo runs on free tiers; every AI step has a mock/fallback mode |

### Non-goals (prototype)

- Payments, invoices, subscription billing (pricing pages are static; "subscription active" is an admin toggle).
- Real university integrations (LMS/ERP) and real ATS integrations.
- Public university rankings.
- Native mobile apps (responsive web only).
- Production-grade scale, SLAs, or compliance certification.

## 5. Users and personas

### 5.1 Roles

| Role | Portal | Description |
|------|--------|-------------|
| **Student** | `student.aptohire.com` | Tech and management students (Tier-2/3 focus) |
| **University user** (TPO / dept admin) | `university.aptohire.com` | IT/CS/Commerce/Management schools |
| **Organization recruiter** | `organization.aptohire.com` | Verified organizations: corporates, start-ups |
| **Platform admin** | `admin.aptohire.com` | Approves universities and organizations, reviews borderline audits, handles tickets |

### 5.2 Personas (from the idea document)

| Persona | Segment | Goal | Pain | How AptoHire helps |
|---------|---------|------|------|--------------------|
| **Raju**, 20 | Student, Tier 3/2 | Get job placement | Resume not getting shortlisted | Verified proof of skill improves visibility to employers |
| **Riya**, 18 | Student | Get a job / internship | No skills yet; too many resources | AI assigns a level-appropriate real-world project |
| **Priya**, 21 | Student | Good-paying, skill-based job | Cannot keep resume/profile updated | Profile manager keeps the digital resume current; skill-based ranking |
| **Uni A** | Tier-3 university | Placement and reputation | Theory–practical gap; no placement analytics | Skill and placement analytics; curriculum-gap signals |
| **Org A** | Corporate | Hire skilled people at minimum hiring and training cost | Unverified skills; bad hires; high cost | Verified, anonymized best-fit candidates with proof |

## 6. Core user journey

1. **Register & verify.** Student registers and is verified against a university (roster match, student-ID check, or unverified).
2. **Pick a target.** Student enters a target skill or role.
3. **Get a project.** AI assigns a real-world project at the right level.
4. **Build & submit.** Student submits title, description, **3-minute demo video**, documents, live link and/or GitHub link, and an AI-use disclosure.
5. **Audit.** The multimodal audit engine scores the work against a rubric with explanations. The student sees a **skill scorecard**; skills scoring **above 50** become **Verified**.
6. **Appeal.** If unsatisfied, the student raises a ticket; an admin reviews with a different reviewer.
7. **Employer posts a job.** The system shows anonymized ranked candidates with "why they match".
8. **Consent.** Organization requests access; student accepts or declines; **only then** is identity and full data shared.
9. **University insight.** The university sees analytics (verified skills, placements, unmatched-demand skills).
10. **Lifecycle.** The profile persists after graduation, dropout, or move to another university.

## 7. Scope

### 7.1 MVP features (the three headline features)

| Headline feature | What it means in the prototype |
|------------------|--------------------------------|
| **AI Video & Audio Skill Audit Engine** | Multimodal audit of video (audio + visual) + script/transcript + code/docs/links → rubric scores, rationale, evidence links |
| **Living Skill Graph & Dynamic Scorecard** | Per-skill scores that update as projects are audited and profile sources sync; graph visualization; downloadable verified digital resume |
| **Anonymized Matchmaking** | Blind candidate cards, vector + structured matching, consent-gated reveal. Marketed as *"zero-knowledge anonymized matchmaking"*; technically implemented as pseudonymization + consent-gated access control (see architecture.md §9) |

### 7.2 Build order

1. Auth, roles, portals, verified affiliation, profile
2. Project assignment and submission (incl. video upload)
3. AI audit engine (agent mode: `mock` → `direct` → `n8n`)
4. Scorecard and living skill graph
5. Employer view: jobs and anonymized candidate cards
6. Consent request → accept → reveal
7. University analytics
8. Admin console, appeals, resume download + verification page
9. Seed data, demo script, polish

### 7.3 Portals and domains

| Host | Purpose |
|------|---------|
| `aptohire.com` | Marketing site, pricing (static), sign-up chooser, public credential verification (`/verify/:id`), legal/privacy pages |
| `student.aptohire.com` | Student portal |
| `university.aptohire.com` | University portal |
| `organization.aptohire.com` | Organization portal |
| `admin.aptohire.com` | Admin console (not linked publicly) |

One Vite + React codebase serves all hosts; the portal is resolved from the hostname (with a path-prefix fallback for free `*.vercel.app` previews and local dev). See architecture.md §3.

## 8. Functional requirements (summary)

Full list with IDs, priorities and acceptance criteria is in **[features.md](./features.md)**. Summary:

| Area | Summary |
|------|---------|
| Identity & access | Email + password / OTP login per portal; role-based routing; one permanent *person* record separate from login and affiliations |
| University onboarding | Approved via admin; roster upload (CSV); student sees "verified university" symbol; unregistered-university students get "unverified" affiliation that does not affect scores |
| Projects | AI project assignment from a curated template library with per-student variation; manual "upload my own project" path |
| Submission | Title, description, mandatory 3-min video, documents, live link, GitHub link, AI-use disclosure |
| Audit | Multimodal audit; rubric scores per skill; rationale; confidence; borderline results queued for human review |
| Scorecard & graph | Dynamic per-skill scores, levels, verified badges, evidence links, skill graph |
| Profile manager | Maintains affiliations and lifecycle status; syncs GitHub (OAuth, read-only) and LinkedIn data (via export upload) only with explicit, revocable consent |
| Digital resume | Downloadable PDF with QR/link to public verification page |
| Matching | Job posting → structured + vector match → anonymized ranked cards with reasons and confidence |
| Consent | Access request → student accepts/declines → scoped reveal → withdrawable |
| University analytics | Verified skills, placement status (placed / not placed / unknown), unmatched-demand skills, alumni/dropout handling |
| Appeals | Student ticket → admin reviewer → decision recorded |
| Feedback | Organizations give structured feedback to students |

## 9. Security and authority rules

These rules follow the idea document and are enforced in the database with Row-Level Security (policies live in one migration file so they can be tightened later):

| Actor | Can see | Cannot see |
|-------|---------|-----------|
| Universities | Their own students' data; **all organizations and job posts** | Other universities; other universities' students |
| Students | Their own data; limited public info of universities and organizations | Other students |
| Organizations | **All universities (public info)**; **other organizations**; anonymized candidate cards | University students' data (until student consent); other candidates' identities |
| Admin | Everything needed for moderation, via audited access | — |

Additional product rules:

- Identity is revealed to an organization **only after the student accepts** that organization's request.
- Every table has RLS enabled; the service-role key never leaves the server side.
- An organization's access can be withdrawn by the student at any time.

## 10. Non-functional requirements

| Category | Requirement |
|----------|-------------|
| Performance | Automated audit result target < 10 min in `direct`/`n8n` mode; < 2 min in `mock` mode. First contentful paint < 2 s on a mid-range phone over 4G |
| Cost | Runs on free tiers; AI calls have per-user daily caps and a global kill switch |
| Reliability | Every AI step has a non-AI fallback (`mock` mode, rule-based matching); demo works offline from AI providers |
| Privacy | Synthetic/fictional data only in the demo environment; PII minimized; student ID numbers stored hashed; no ID-card images stored |
| Security | RLS everywhere; signed webhooks (HMAC) to the agent builder; uploads type- and size-checked; audit log of sensitive reads |
| Accessibility | WCAG 2.2 AA target: contrast, keyboard focus, reduced motion, form labels |
| Responsive | Fully usable at 360 px width and up |
| Observability | `agent_runs` table with status, latency, token estimate, error |
| Browser support | Latest two versions of Chrome, Edge, Safari, Firefox |

## 11. Success metrics (prototype pilot targets)

All targets are starting hypotheses to be adjusted after the first pilot.

| Group | Metric | Target |
|-------|--------|--------|
| Student | Onboarded students who submit a first project | ≥ 60% |
| Student | Time to automated result | < 10 min |
| Student | Verified students in pilot | 50–100 |
| Student | Appeals overturned | < 10% |
| AI quality | AI vs human reviewer agreement (within one level, 30-project check) | ≥ 80% |
| AI quality | False-pass rate | tracked and reviewed weekly |
| AI quality | AI cost per assessment | within free limits |
| Employer | Candidates viewed per employer | ≥ 5 |
| Employer | Access requests accepted | ≥ 50% |
| University | Roster uploaded, active students, weekly dashboard use | tracked |
| Safety | Consent breaches / cross-university data leaks | **0** |

**Initial target (first ~3 months):** 2 universities (one with institutional email, one without), 1 department (IT/CS), 50–100 students, 1 skill family, 3–5 verified organizations.

## 12. Demo data and storyline

Fictional data only. Full seed spec: architecture.md §13.

| | Uni A | Uni B | Uni C | Uni D |
|---|-------|-------|-------|-------|
| Status | Tier 2, direct outreach, **approved** | Tier 3, direct outreach, **approved** | **Applied online, pending approval** | **Not registered** |
| Student sign-up | University email | Personal email + student ID check | — | Personal email (unverified) |
| Next-semester | Aman | Nikhil | Sumit | — |
| First year | Ajay | Neha | Sourav | — |
| Second year | Aarav | Naman | Sam | Priya |
| Third year | Akshit | Naveen | Shiva | Adarsh |
| Dropout | Aarti | Nita | Shruti | — |
| Alumni | Avi | Niya | Sohan | — |

Lifecycle edge cases seeded to prove "no double entry":

- **Avi** (alumnus, Uni A) starts a master's at **Uni B** (registered) → new affiliation, old one closed, scores kept.
- **Niya** (alumna, Uni B) starts a master's at **Uni D** (not registered) → affiliation marked *Unverified*; scores and job access unaffected.
- **Aarti** (dropout, Uni A) joins Uni B.
- **Nita** (dropout, Uni B) has no new university.
- **Sohan** (alumnus, Uni C) works at Org A and never updates his profile → the profile manager keeps it current from consented sources.

Organizations: **Org A** (mid-size corporate), **Org B** (start-up), one recruiter user each. One **admin**.

### 5–7 minute demo script

1. **Admin** approves Uni C → its students can now register (portal separation, 30 s).
2. **Student (Aarav, Uni A)** logs in on `student.` → sees verified-university symbol → asks for a project in "React frontend" → gets a project brief (60 s).
3. Aarav submits a project with video + GitHub link → watches the **audit progress** → scorecard with **Proof Ring**, verified badge, rationale (90 s).
4. **Organization (Org A)** on `organization.` posts a job → sees **anonymized ranked cards** with reasons (60 s).
5. Org A sends an **access request** → Aarav accepts on `student.` → identity revealed (60 s).
6. **University (Uni A)** sees analytics update and an unmatched-skill alert (45 s).
7. Aarav downloads the **digital resume** and scans its QR → public verification page (30 s).
8. Closing: show Avi/Niya lifecycle — scores persisted across universities (30 s).

## 13. Constraints to design around

- **Free-tier limits.** Supabase free (small DB/storage, projects pause after inactivity), Vercel Hobby (non-commercial use), free LLM quotas (rate-limited, variable). Mitigation: `mock` agent mode, compression/size caps on video, keep-alive ping, regular DB export.
- **Video evidence.** Video is mandatory per the idea; the prototype enforces a 3-minute cap and a file-size cap, and supports an unlisted-link alternative if upload fails (`REQUIRE_VIDEO` flag).
- **n8n-style builder needs an always-on host** for live demos; `direct` mode (edge function → LLM) is the fallback.
- **Synthetic data only** in demo and development.

## 14. Decisions log

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Single codebase, host-based portal routing | One deploy, shared components, per-subdomain login |
| D2 | Pass mark = **50** (config `PASS_MARK`) | As specified; also store a level and flag 40–60 as "borderline → admin review" |
| D3 | Video is **mandatory** (flag `REQUIRE_VIDEO`) | As specified |
| D4 | Visibility rules as in §9 | As specified; isolated in `rls_visibility.sql` |
| D5 | Agent builder is **n8n-style** but behind an adapter with `mock` and `direct` modes | Demo never depends on one external service |
| D6 | One permanent `students` record + `affiliations` | Solves double entry across lifecycle changes |
| D7 | LinkedIn data enters via **user-uploaded export**; GitHub via **OAuth read-only** | Technically feasible integration paths |
| D8 | "Zero-knowledge" is a brand phrase; implementation is pseudonymization + consent-gated access | Describes behavior accurately in technical docs |
| D9 | Admin portal is a separate subdomain | Smaller blast radius, MFA enforced |

## 15. Open questions

1. Final product name and domain (`aptohire.com` availability not yet checked).
2. Which single skill family to demo first (suggested: **Web / React frontend**).
3. Preferred free LLM provider order (default: Gemini Flash-class → Groq → OpenRouter free models).
4. Where to host the n8n-style builder (always-on free VM, small paid VPS, or run locally for demos).

## 16. Milestones

| Phase | Outcome | Exit criteria |
|-------|---------|---------------|
| **P0 Foundations** | Repo, CI, Supabase project, schema + RLS, portal routing, design tokens | All five hosts resolve to the correct shell; RLS tests pass |
| **P1 Identity** | Auth, roles, universities, roster import, affiliations | Seeded users can log in; verification levels display correctly |
| **P2 Projects & Submission** | Assignment, submission form, video upload | Student can submit a complete project |
| **P3 Audit & Scorecard** | Agent adapter (`mock`/`direct`/`n8n`), audit pipeline, scorecard, skill graph | Scorecard appears via Realtime; appeals possible |
| **P4 Matching & Consent** | Jobs, anonymized cards, request/accept/reveal | Reveal only after acceptance; verified by test |
| **P5 University & Admin** | Analytics, admin console, ticket review, borderline queue | Demo script steps 1, 6 work |
| **P6 Polish & Demo** | Resume PDF + QR, verification page, seed, empty states, accessibility pass | Full demo script runs without errors |
