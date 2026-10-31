# AptoHire — Features

> Companion to [prd.md](./prd.md). Architecture details: [architecture.md](./architecture.md). Agent contracts: [agent.md](./agent.md). UI rules: [design.md](./design.md).

**Priority:** `P0` = required for the demo script · `P1` = should have · `P2` = nice to have
**Status:** `[ ]` todo · `[~]` in progress · `[x]` done (coding agents: update this as you go)
**Portals:** `ROOT` aptohire.com · `STU` student. · `UNI` university. · `ORG` organization. · `ADM` admin.

---

## 1. Platform and identity

| ID | Feature | Portal | Pri | Status |
|----|---------|--------|-----|--------|
| F-ID-01 | **Host-based portal routing** (hostname → portal; fallback to `/student`, `/university`, `/organization`, `/admin` path prefixes and `?portal=` in dev) | all | P0 | [ ] |
| F-ID-02 | **Per-portal login/sign-up** (email + password; email OTP optional) | STU, UNI, ORG, ADM | P0 | [ ] |
| F-ID-03 | **Role guard**: a user may only enter the portal matching their role; wrong-portal visit shows a "Go to your portal" screen | all | P0 | [ ] |
| F-ID-04 | **Session management**: short-lived tokens, sign out on all devices, session list | all | P1 | [ ] |
| F-ID-05 | **MFA (TOTP)** mandatory for admin; optional for others | ADM | P1 | [ ] |
| F-ID-06 | **Cookie / privacy notice** banner | ROOT, all | P1 | [ ] |
| F-ID-07 | **Demo account switcher** (dev/demo env only): one-click login as any seeded user | all | P0 | [ ] |
| F-ID-08 | **Change login email** requires verification of the new address | STU | P1 | [ ] |

**Acceptance (F-ID-01/03):** opening `student.localhost:5173` renders the student shell; logging in as an organization user there shows the wrong-portal screen with a link to `organization.`; no portal data is fetched for the wrong role.

---

## 2. Marketing site (ROOT)

| ID | Feature | Pri | Status |
|----|---------|-----|--------|
| F-MK-01 | Landing page: hero (live scorecard preview), how it works (3 audiences), proof-over-resumes pitch, CTA to each portal | P0 | [ ] |
| F-MK-02 | Portal chooser / sign-up router ("I'm a student / university / organization") | P0 | [ ] |
| F-MK-03 | Pricing page (static): university license, organization plans, student free | P1 | [ ] |
| F-MK-04 | **Public verification page** `/verify/:credentialId` showing a student's verified skills, levels, issue date, and verification status — respects the student's sharing settings | P0 | [ ] |
| F-MK-05 | Privacy, terms, AI-use & fairness statement pages | P1 | [ ] |
| F-MK-06 | "Apply for university access" form (creates Uni C–type pending application) | P0 | [ ] |
| F-MK-07 | "Request organization access" form | P1 | [ ] |

---

## 3. Student portal (STU)

### 3.1 Onboarding and affiliation

| ID | Feature | Pri | Status |
|----|---------|-----|--------|
| F-ST-01 | **Registration with university detection**: if email domain matches an approved university → roster match → *Verified (roster)* | P0 | [ ] |
| F-ST-02 | **Personal-email registration with student-ID check** (Uni B pattern): ID number hashed and matched to roster → *Verified (student ID)*; no ID image stored | P0 | [ ] |
| F-ST-03 | **Unregistered university** (Uni D pattern): student enters university name → affiliation *Unverified*; **scores and job access unaffected** | P0 | [ ] |
| F-ST-04 | **Verified-university symbol** next to the university on profile and cards | P0 | [ ] |
| F-ST-05 | **Profile**: name, photo, headline, bio, location, links, languages, education timeline (affiliations), target skills/roles | P0 | [ ] |
| F-ST-06 | **Lifecycle status** shown and managed: Incoming · Enrolled (year) · Dropout · Alumni · Masters | P0 | [ ] |
| F-ST-07 | **Claim & merge**: when a new university uploads a roster that includes an existing person (same verified email/ID hash), the student confirms a new affiliation instead of creating a new account | P0 | [ ] |

**Acceptance (F-ST-03):** Niya moves to Uni D (unregistered) → her affiliation shows *Unverified*; her skill scores, badges, and job matches are unchanged.
**Acceptance (F-ST-07):** Avi (Uni A alumnus) is added to Uni B's roster → he sees "Confirm new university"; after confirming, Uni A affiliation is closed (Alumni), Uni B affiliation opens; no second account exists.

### 3.2 Projects

| ID | Feature | Pri | Status |
|----|---------|-----|--------|
| F-ST-10 | **Project assistant chat**: student enters a skill/role and gets a real-world project brief (title, scenario, deliverables, level, rubric preview, suggested stack, estimated effort) | P0 | [ ] |
| F-ST-11 | Briefs are built from a **curated template library** + per-student variation (data, constraints, twist); similarity check against prior assignments | P1 | [ ] |
| F-ST-12 | **My projects** list with status: Assigned → In progress → Submitted → Auditing → Scored / Needs review / Appealed | P0 | [ ] |
| F-ST-13 | **Upload my own project** (skill learned elsewhere): same submission form without an assignment | P0 | [ ] |

### 3.3 Submission

| ID | Feature | Pri | Status |
|----|---------|-----|--------|
| F-ST-20 | **Submission form**: title, description, **mandatory 3-min demo video**, related documents, live-project URL, GitHub URL (tech), skill(s) claimed, **AI-use disclosure** | P0 | [ ] |
| F-ST-21 | **Video upload** with client-side checks: type (mp4/webm/mov), duration ≤ 3:10, size cap (default 50 MB), resumable upload, progress, preview; fallback: unlisted video link | P0 | [ ] |
| F-ST-22 | **Draft autosave** and resume | P1 | [ ] |
| F-ST-23 | **Originality prompts**: 2–3 questions tied to the student's own code/doc, answered in the video or text | P1 | [ ] |
| F-ST-24 | Document upload (PDF, DOCX, MD, ZIP ≤ cap) with type and size checks | P0 | [ ] |

**Acceptance (F-ST-20/21):** submission cannot be sent without a video (or video link) when `REQUIRE_VIDEO=true`; a 4-minute video is rejected with a message saying how to fix it.

### 3.4 Audit, scorecard, skill graph

| ID | Feature | Pri | Status |
|----|---------|-----|--------|
| F-ST-30 | **Live audit progress** (Realtime): Received → Reading code & docs → Watching video → Scoring → Ready; each step with a plain-language description | P0 | [ ] |
| F-ST-31 | **Skill scorecard**: per-skill score (0–100), level, **Proof Ring**, verified badge when score > `PASS_MARK` (50), confidence, rationale | P0 | [ ] |
| F-ST-32 | **Evidence links**: each rubric criterion links to the evidence used (video timestamp, file, repo path/commit, doc excerpt) | P0 | [ ] |
| F-ST-33 | **Living skill graph**: nodes = skills (size = score, colour = verified/in-progress), edges = related skills; click a node to see projects and evidence | P0 | [ ] |
| F-ST-34 | **Score history** per skill (line chart across audits) | P1 | [ ] |
| F-ST-35 | **Next-step suggestions**: "To reach the next level, build…" (links to F-ST-10) | P1 | [ ] |
| F-ST-36 | **Appeal**: raise ticket from any scored submission with a reason; see status and decision | P0 | [ ] |
| F-ST-37 | **Borderline notice**: results in 40–60 show "Under human review" until an admin confirms | P1 | [ ] |

### 3.5 Profile manager, resume, sharing

| ID | Feature | Pri | Status |
|----|---------|-----|--------|
| F-ST-40 | **Connected sources** page: GitHub (OAuth, read-only), LinkedIn (upload data export / paste profile text), manual links. Each source has its own **revocable consent toggle** and "last synced" | P0 | [ ] |
| F-ST-41 | **Profile manager agent** proposes profile updates (new repos, roles, skills); student approves or auto-approves per source | P1 | [ ] |
| F-ST-42 | **Digital resume**: web view + **PDF download** with verification **QR code/link** to `/verify/:id` | P0 | [ ] |
| F-ST-43 | **Visibility settings**: what is shown on the public verification page and on anonymized cards | P1 | [ ] |
| F-ST-44 | **Data export and delete my account** | P1 | [ ] |

### 3.6 Opportunities and consent

| ID | Feature | Pri | Status |
|----|---------|-----|--------|
| F-ST-50 | **Access requests inbox**: organization name, role, message, what data they ask for, duration | P0 | [ ] |
| F-ST-51 | **Accept / decline**; accept lets the student choose scope (profile, scorecard, projects, contact details) and duration | P0 | [ ] |
| F-ST-52 | **Withdraw access** at any time; active grants list | P0 | [ ] |
| F-ST-53 | **Feedback received** from organizations (structured options) | P1 | [ ] |
| F-ST-54 | **Notification centre** (in-app) | P0 | [ ] |
| F-ST-55 | Matched jobs feed (relevance + reasons), if student opted in to discovery | P2 | [ ] |

---

## 4. University portal (UNI)

| ID | Feature | Pri | Status |
|----|---------|-----|--------|
| F-UN-01 | **Application status**: Pending → Approved / Rejected (set by admin); read-only dashboard preview while pending | P0 | [ ] |
| F-UN-02 | **Roster upload (CSV)** with column mapping, validation report, duplicate detection; stores minimal fields (name, email, year, program, status, student-ID hash) | P0 | [ ] |
| F-UN-03 | **Roster management**: update year, mark Dropout / Alumni, add single student; changes update the **affiliation record only** (platform never edits the university's own master record) | P0 | [ ] |
| F-UN-04 | **Students list** with verification level, claimed/unclaimed, verified skills count, lifecycle status — only this university's students | P0 | [ ] |
| F-UN-05 | **Student detail** (own students): scorecard summary and verified skills; project files only where the student consented | P1 | [ ] |
| F-UN-06 | **Analytics dashboard**: verified students, skills distribution, average score by skill, activation (invited → registered → submitted → verified), cohort filters | P0 | [ ] |
| F-UN-07 | **Placement & alumni view**: Placed / Not placed / **Unknown**; sourced from university entry or student confirmation; "last updated" shown | P0 | [ ] |
| F-UN-08 | **Unmatched-demand alerts**: when an organization posts a job and no match exists, the university sees *counts and reasons* (no eligible candidates, incomplete assessments, insufficient evidence, skills mismatch, opted out, not yet assessed) and the demanded skill — never student identities | P0 | [ ] |
| F-UN-09 | **Curriculum gap report**: top demanded skills vs. verified supply | P1 | [ ] |
| F-UN-10 | **Organizations directory and job posts** (all organizations and jobs, per the authority rules) | P1 | [ ] |
| F-UN-11 | **Own trends over time** (no cross-university comparison and no public ranking) | P1 | [ ] |
| F-UN-12 | Team members (TPO, department admins) with roles | P2 | [ ] |

---

## 5. Organization portal (ORG)

| ID | Feature | Pri | Status |
|----|---------|-----|--------|
| F-OR-01 | **Organization onboarding** → admin approval → *Verified organization* badge | P0 | [ ] |
| F-OR-02 | **Subscription status** (prototype: admin-toggled; paywall screen if inactive) | P1 | [ ] |
| F-OR-03 | **Post a job**: title, description (paste JD), required skills + minimum level, location/mode, openings | P0 | [ ] |
| F-OR-04 | **JD reader**: agent extracts skills and levels from pasted text; recruiter edits | P0 | [ ] |
| F-OR-05 | **Ranked anonymized candidates** per job: alias (e.g., "Candidate K7F2"), university *category* (tier / type) — **university name hidden until consent**, verified skills, scores, "why they match" reasons, confidence | P0 | [ ] |
| F-OR-06 | **Candidate card detail**: skill breakdown, proof summary (no identity, no raw files) | P0 | [ ] |
| F-OR-07 | **Request access**: select candidate(s), message, requested scope, duration | P0 | [ ] |
| F-OR-08 | **Accepted candidates**: full profile, resume, contact details, project evidence — within the granted scope and duration; shows expiry | P0 | [ ] |
| F-OR-09 | **Pipeline**: Matched → Requested → Accepted → Interviewing → Offered/Closed (manual status) | P1 | [ ] |
| F-OR-10 | **Structured feedback** to students (reviewed option lists + optional short note) | P1 | [ ] |
| F-OR-11 | **Match explanation drawer**: structured skill/level match, vector similarity contribution, gaps | P1 | [ ] |
| F-OR-12 | Directory of universities and other organizations (public info only for universities; per the authority rules for organizations) | P1 | [ ] |
| F-OR-13 | Notify when a *new* verified candidate matches an open job | P1 | [ ] |
| F-OR-14 | Team members and recruiter roles | P2 | [ ] |

**Acceptance (F-OR-05/08):** before acceptance, no API response for the organization contains the student's name, email, photo, university name, or file URLs (verified by an automated RLS/API test). After acceptance, only the granted scope fields appear; after expiry or withdrawal they disappear.

---

## 6. Admin portal (ADM)

| ID | Feature | Pri | Status |
|----|---------|-----|--------|
| F-AD-01 | **University applications**: approve / reject with note (approving Uni C unlocks its students' registration) | P0 | [ ] |
| F-AD-02 | **Organization approvals** | P0 | [ ] |
| F-AD-03 | **Borderline audit queue** (40–60) with side-by-side AI rationale and evidence; confirm or adjust score | P1 | [ ] |
| F-AD-04 | **Appeal tickets**: acknowledge, assign a *different* reviewer, decide, record reason; outcome feeds rubric improvement log | P0 | [ ] |
| F-AD-05 | **Agent runs monitor**: status, latency, mode (`mock`/`direct`/`n8n`), errors, estimated tokens; retry failed runs | P0 | [ ] |
| F-AD-06 | **Kill switch & config**: toggle agent mode, `PASS_MARK`, `REQUIRE_VIDEO`, daily AI caps | P0 | [ ] |
| F-AD-07 | **Skill taxonomy and project template library** editor | P1 | [ ] |
| F-AD-08 | **Audit log viewer** (sensitive reads, reveals, admin actions) | P1 | [ ] |
| F-AD-09 | **Users and roles** management; impersonation is *not* allowed | P1 | [ ] |
| F-AD-10 | **Seed/reset demo data** button (non-production only) | P0 | [ ] |
| F-AD-11 | AI-vs-human agreement report (feeds the ≥ 80% target) | P2 | [ ] |

---

## 7. AI agent features

Full contracts in [agent.md](./agent.md).

| ID | Feature | Agent | Pri | Status |
|----|---------|-------|-----|--------|
| F-AI-01 | **Multimodal proof audit** (video audio + visual + script + code/docs/links → rubric scores, rationale, evidence refs, confidence) | Proof Audit Engine | P0 | [ ] |
| F-AI-02 | **Mock mode**: deterministic realistic audits for demos without API keys | Proof Audit Engine | P0 | [ ] |
| F-AI-03 | **Project assignment** from templates + student level/skills | Project Assigner | P0 | [ ] |
| F-AI-04 | **Predictive blind matching**: structured skill-level match + vector rerank, reasons, confidence; blind inputs only | Blind Matching Agent | P0 | [ ] |
| F-AI-05 | **JD → skills** extraction | Blind Matching Agent | P0 | [ ] |
| F-AI-06 | **Profile manager**: lifecycle updates (rule-based), source sync proposals (LLM-assisted), resume text refresh | Profile Manager | P1 | [ ] |
| F-AI-07 | **Explanation writer** for scorecards and match reasons in plain language | all | P0 | [ ] |
| F-AI-08 | **Similarity/originality check** between submissions (text + repo fingerprint) | Proof Audit Engine | P2 | [ ] |
| F-AI-09 | **Provider adapter** (Gemini → Groq → OpenRouter) with retries and quota-aware fallback | all | P1 | [ ] |
| F-AI-10 | **Per-user and global AI quotas**, visible in admin | all | P1 | [ ] |

---

## 8. Cross-cutting

| ID | Feature | Pri | Status |
|----|---------|-----|--------|
| F-XC-01 | **RLS on every table** + automated policy tests (see architecture.md §7) | P0 | [ ] |
| F-XC-02 | **Audit log** for: identity reveal, access grant/withdraw, admin actions, appeals | P0 | [ ] |
| F-XC-03 | **Notifications** (in-app; email optional via Supabase SMTP) | P0 | [ ] |
| F-XC-04 | **Realtime** updates for audit status, requests, notifications | P0 | [ ] |
| F-XC-05 | **Empty / error / loading states** for every list and form (see design.md §10) | P0 | [ ] |
| F-XC-06 | **Keyboard and screen-reader support** for core flows | P1 | [ ] |
| F-XC-07 | **Rate limiting** on auth, uploads, agent triggers | P1 | [ ] |
| F-XC-08 | **Upload scanning** (type sniffing, size, extension allow-list; AV scan optional) | P1 | [ ] |
| F-XC-09 | **Keep-alive ping** + scheduled DB export for free-tier projects | P1 | [ ] |
| F-XC-10 | **i18n-ready strings** (English first; Hindi next) | P2 | [ ] |

---

## 9. Demo-critical path (all P0)

`F-ID-01 → F-ID-07 → F-AD-01 → F-ST-01/03 → F-ST-10 → F-ST-20/21 → F-AI-01/02 → F-ST-30/31/32/33 → F-OR-03/04/05 → F-OR-07 → F-ST-50/51 → F-OR-08 → F-UN-06/08 → F-ST-42 → F-MK-04`

## 10. Skill taxonomy (starter, editable in F-AD-07)

| Family | Skills (examples) | Rubric type |
|--------|-------------------|-------------|
| **Web / Frontend** (demo family) | HTML/CSS, JavaScript, React, TypeScript, Accessibility, API integration, Testing | Code + live app + video |
| Backend | Node.js, Python, SQL, REST design, Auth | Code + docs + video |
| Data | SQL analytics, Python/Pandas, Visualization, ML basics | Notebook + docs + video |
| Management / Commerce *(human-reviewed rubrics later)* | Market analysis, Financial modelling, Project planning, Communication | Document + video, rubric-based |

Levels: **Emerging (0–50, not verified) · Competent (51–69) · Proficient (70–84) · Advanced (85–100)**. **Verified = score > 50** (configurable `PASS_MARK`), so every verified skill has a level of Competent or higher. Scores of 40–60 are flagged *borderline* for human review.
