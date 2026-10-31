# AptoHire — Design

> Companion to [prd.md](./prd.md), [features.md](./features.md), [architecture.md](./architecture.md).
> Brief: **modern, sleek, minimal.** White base, soft gradients, **green** and **orange** accents.

---

## 1. Design direction

**Concept: "Proof you can see."** AptoHire sells trust. The interface is quiet, white, and spacious so that one thing stands out: **evidence**. Every score has a source you can open; every badge shows how it was earned.

- **Green = verified, trusted, done.** Orange = in progress, attention, energy. The two meet in the **Proof Ring**, the signature element.
- **White is the product.** Gradients are a rare, soft wash (hero, portal headers, the ring's arc), never card decoration.
- **Spend boldness in one place:** the Proof Ring and the evidence trail beside it. Everything else is calm and disciplined.

### 1.1 Review notes (choices made against generic defaults)

| First instinct | Changed to | Why |
|---|---|---|
| Mint-and-peach gradient on every card | Gradient only on the hero wash, portal header strip, and the ring arc | Gradient on everything reads as a template and weakens the one place it matters |
| Same rounded card + shadow for all content | Data lives in tables and lists with hairlines; cards only for *candidates* and *requests* (things you act on) | Structure should show what kind of content it is |
| "Verified ✓ 98%" big-number-with-gradient hero | Hero shows a live scorecard with evidence rows you can open | Opens with the most characteristic thing: proof |
| Tracked all-caps eyebrow labels above sections | Plain sentence-case headings; labels only when they carry information | Avoids template chrome |
| One accent word coloured in the headline | Whole headline in ink | Plain and confident |
| Fade-up on every section | One orchestrated moment: score reveal. Other motion only responds to actions | Motion should mean something |
| Photos/avatars of candidates | **Alias glyphs** (generated geometric marks) | Reinforces blind hiring visually |

---

## 2. Colour

### 2.1 Palette

| Token | Hex | Role |
|---|---|---|
| `canvas` | `#FFFFFF` | Page background |
| `mist` | `#F6F8F7` | Subtle surfaces, table headers, rail |
| `hairline` | `#E3E8E5` | Borders, dividers |
| `ink` | `#17261E` | Primary text (deep forest) |
| `moss` | `#5B6A62` | Secondary text, icons |
| `verdant-50` | `#ECFAF2` | Verified surfaces |
| `verdant-100` | `#D2F3E1` | Verified chips, selection |
| `verdant-300` | `#8FE0B2` | Charts, ring end highlights |
| `verdant-600` | `#0E9F5B` | Brand green for **graphics and large elements** |
| `verdant-700` | `#0B7F49` | Primary buttons, links, small green text |
| `verdant-800` | `#0A6139` | Hover/pressed |
| `ember-50` | `#FFF3E8` | Attention surfaces |
| `ember-100` | `#FFE2C7` | Pending chips |
| `ember-300` | `#FFB470` | Chart secondary, ring start highlights |
| `ember-500` | `#FF7A1A` | Brand orange for **graphics, accent buttons** |
| `ember-700` | `#B94A06` | Small orange text on light backgrounds |
| `danger-600` / `danger-50` | `#C4311F` / `#FDECE9` | Errors, destructive actions |

### 2.2 Verified contrast (WCAG)

| Pair | Ratio | Use |
|---|---|---|
| `ink` on `canvas` | 15.8:1 | Body text |
| `moss` on `canvas` / `mist` | 5.7:1 / 5.4:1 | Secondary text |
| `verdant-700` on `canvas` / `verdant-50` | 5.1:1 / 4.7:1 | Links, green text |
| `canvas` on `verdant-700` | 5.1:1 | **Primary button label** |
| `ink` on `ember-500` | 6.0:1 | **Accent button label** |
| `ember-700` on `canvas` / `ember-50` | 5.2:1 / 4.8:1 | Orange text |
| `danger-600` on `canvas` | 5.5:1 | Error text |
| `canvas` on `verdant-600` | 3.4:1 | **Large text (≥ 24 px) and graphics only**, never body text or small labels |

> Do not put white text on `ember-500`. Do not use `verdant-600` or `ember-500` for small text.

### 2.3 Gradients (use sparingly)

| Name | CSS | Where |
|---|---|---|
| `dawn` | `linear-gradient(135deg, #E6F8EE 0%, #FFFFFF 46%, #FFEBD6 100%)` | Hero wash, portal header strip |
| `mesh` | `radial-gradient(60% 60% at 12% 8%, #DDF6E8 0%, transparent 70%), radial-gradient(50% 50% at 92% 88%, #FFE7D0 0%, transparent 70%), #FFFFFF` | Marketing hero and empty-state backdrops |
| `proof-arc` | `conic-gradient(from 200deg, #FF7A1A, #FFB470 30%, #8FE0B2 60%, #0E9F5B)` | Proof Ring arc |
| `verified` | `linear-gradient(135deg, #0E9F5B, #34C98A)` | Verified seal fill |

Rules: at most **one** gradient surface per viewport; never behind body text smaller than 16 px unless the wash is lighter than `#E6F8EE`/`#FFEBD6`; no gradient buttons.

### 2.4 Portal identity (same system, different tint)

| Portal | Header strip | Accent emphasis | Feel |
|---|---|---|---|
| Root | `mesh` | Both | Warm, open |
| Student | `dawn` (green → orange) | Green-led, orange for progress | Encouraging |
| University | `linear-gradient(180deg,#E6F8EE,#FFFFFF)` | Green + slate | Institutional, calm |
| Organization | `linear-gradient(180deg,#FFEBD6,#FFFFFF)` | Orange-led accents, green for verified | Decisive |
| Admin | `mist` flat | Green only | Utilitarian |

Primary buttons are always `verdant-700`; the portal tint shows only in the header strip and accent use.

Light theme only in the prototype. Dark mode is deferred (P2).

---

## 3. Typography

| Role | Typeface | Notes |
|---|---|---|
| Display and headings | **Bricolage Grotesque** (variable; Google Fonts) | Distinctive grotesque with character at large sizes; weight 600–700 for display, tight tracking |
| Body and UI | **Instrument Sans** (Google Fonts) | Clean, slightly condensed, very legible at 14–16 px |
| Code, hashes | **JetBrains Mono** | Code snippets and technical identifiers only, never for decorative labels |

Fallback stacks: `"Bricolage Grotesque", "Segoe UI", system-ui, sans-serif` · `"Instrument Sans", "Segoe UI", system-ui, sans-serif`. Load with `font-display: swap`, preconnect, and limit to the weights in use (400, 500, 600 body; 600, 700 display).

### 3.1 Scale (px / line-height, tracking)

| Token | Size | Use |
|---|---|---|
| `display-xl` | 64 / 68, −0.025em | Marketing hero only |
| `display-l` | 44 / 50, −0.02em | Section headlines |
| `h1` | 32 / 38, −0.015em | Page titles |
| `h2` | 24 / 32, −0.01em | Section titles |
| `h3` | 20 / 28 | Card and panel titles |
| `body-l` | 18 / 30 | Lead paragraphs |
| `body` | 16 / 26 | Default |
| `small` | 14 / 22 | Tables, metadata |
| `caption` | 12.5 / 18 | Helper text, timestamps |

Rules: sentence case everywhere; line length **≤ 68 characters**; left-aligned text (never justified; centred only for single-line empty states and the closing call to action); numbers use `font-variant-numeric: tabular-nums`; scores in Bricolage 600.

---

## 4. Layout, spacing, shape, elevation

### 4.1 Spacing and grid

4 px base: `4 · 8 · 12 · 16 · 24 · 32 · 48 · 72 · 112`. Content width max **1200 px**; 12-column grid (24 px gutter ≥ 1024 px; 16 px below). Page padding 24 px (desktop), 16 px (mobile). Section rhythm on marketing: 112 px desktop / 72 px mobile.

### 4.2 Shape — radius encodes hierarchy

| Token | Radius | Use |
|---|---|---|
| `r-control` | 10 px | Inputs, buttons, chips (chips full-pill) |
| `r-panel` | 16 px | Candidate cards, request cards, dialogs |
| `r-feature` | 28 px | Hero panel, scorecard panel |
| `r-full` | 999 px | Pills, avatars, seal |

### 4.3 Elevation

Most things are **flat with a hairline border**. Shadow marks only what floats:

| Level | Shadow | Use |
|---|---|---|
| 0 | none, `1px solid hairline` | Tables, panels, cards at rest |
| 1 | `0 1px 2px rgba(23,38,30,.06), 0 8px 24px -10px rgba(23,38,30,.14)` | Popovers, menus, candidate card on hover/focus |
| 2 | `0 2px 4px rgba(23,38,30,.06), 0 24px 48px -16px rgba(23,38,30,.22)` | Dialogs, side sheets |

---

## 5. Tokens (copy into `src/styles/tokens.css`)

```css
:root {
  --canvas: #ffffff;  --mist: #f6f8f7;  --hairline: #e3e8e5;
  --ink: #17261e;     --moss: #5b6a62;

  --verdant-50: #ecfaf2;  --verdant-100: #d2f3e1;  --verdant-300: #8fe0b2;
  --verdant-600: #0e9f5b; --verdant-700: #0b7f49;  --verdant-800: #0a6139;

  --ember-50: #fff3e8;  --ember-100: #ffe2c7;  --ember-300: #ffb470;
  --ember-500: #ff7a1a; --ember-700: #b94a06;

  --danger-600: #c4311f; --danger-50: #fdece9;

  --grad-dawn: linear-gradient(135deg, #e6f8ee 0%, #ffffff 46%, #ffebd6 100%);
  --grad-mesh:
    radial-gradient(60% 60% at 12% 8%, #ddf6e8 0%, transparent 70%),
    radial-gradient(50% 50% at 92% 88%, #ffe7d0 0%, transparent 70%), #ffffff;
  --grad-verified: linear-gradient(135deg, #0e9f5b, #34c98a);

  --r-control: 10px; --r-panel: 16px; --r-feature: 28px;
  --shadow-1: 0 1px 2px rgba(23,38,30,.06), 0 8px 24px -10px rgba(23,38,30,.14);
  --shadow-2: 0 2px 4px rgba(23,38,30,.06), 0 24px 48px -16px rgba(23,38,30,.22);

  --font-display: "Bricolage Grotesque", "Segoe UI", system-ui, sans-serif;
  --font-body: "Instrument Sans", "Segoe UI", system-ui, sans-serif;

  --ease-out: cubic-bezier(.2, .8, .2, 1);
  --dur-fast: 150ms; --dur-base: 220ms; --dur-reveal: 900ms;
}
[data-portal="student"]      { --portal-strip: var(--grad-dawn); }
[data-portal="university"]   { --portal-strip: linear-gradient(180deg, #e6f8ee, #fff); }
[data-portal="organization"] { --portal-strip: linear-gradient(180deg, #ffebd6, #fff); }
[data-portal="admin"]        { --portal-strip: var(--mist); }
@media (prefers-reduced-motion: reduce) {
  * { animation-duration: .001ms !important; transition-duration: .001ms !important; }
}
```

Tailwind: map these in `theme.extend.colors` (`canvas`, `mist`, `hairline`, `ink`, `moss`, `verdant.{50,100,300,600,700,800}`, `ember.{50,100,300,500,700}`, `danger`), `borderRadius` (`control`, `panel`, `feature`), `boxShadow` (`float`, `modal`), `fontFamily` (`display`, `body`).

---

## 6. Signature elements

### 6.1 Proof Ring (the memorable element)

A circular score gauge that tells the whole story in one glance.

| Property | Spec |
|---|---|
| Size | 240 px (scorecard hero), 96 px (list rows), 56 px (compact) |
| Track | `hairline`, stroke 12 px (hero) |
| Arc | `proof-arc` conic gradient (orange start → green end), round caps, length = score ÷ 100 |
| Pass notch | Small tick at 50% marking the pass mark (`PASS_MARK`) |
| Centre | Score in Bricolage 600 (hero 64 px), caption below: level (e.g. "Competent") |
| Verified state | Verified seal (check in `verified` gradient circle, 40 px) sits on the ring at the top right; caption reads "Verified · Competent" |
| Not verified | Arc is solid `ember-500`; caption "Not verified yet · 9 points to go" |
| Under review | Arc `ember-300`, dashed track segment at the end, caption "Under human review" |
| Accessibility | `role="img"` with `aria-label="React, score 72 of 100, Proficient, verified"`; the number is real text |

**Reveal (the one orchestrated motion):** arc draws from 0 to the score over **900 ms** (`ease-out`), the number counts up in sync, the seal scales 0.8 → 1 with a 180 ms settle at the end. Plays once when a new score arrives. With reduced motion: shows the final state immediately.

### 6.2 Evidence trail

Beside every score, a list of **evidence rows**, each a criterion with a score bar, a one-line rationale, and **evidence chips** (`Video 01:42`, `src/App.tsx`, `README.md`, `Live site`). Selecting a chip opens a side sheet with the actual evidence (video jumps to the timestamp, code shows the lines). *Structure here is information: the rows exist because the score is explainable.*

### 6.3 Verified seal and status chips

| Chip | Look | Meaning |
|---|---|---|
| **Verified** | `verdant-100` fill, `verdant-800` text, seal icon | Score above the pass mark |
| **Under review** | `ember-100` fill, `ember-700` text | Borderline; human review pending |
| **Pending** | `ember-50` fill, `ember-700` text | Waiting for a person to act |
| **Unverified university** | White, dashed `hairline` border, `moss` text | Affiliation not confirmed (never lowers scores) |
| **Verified university** | `verdant-50` fill, small seal | Roster-matched |
| **Declined / Closed** | `mist` fill, `moss` text | Finished states |

### 6.4 Alias glyph

A 48 px generated mark per candidate alias: 3–4 overlapping circles/arcs from a deterministic seed (hash of alias), using only palette greens/oranges on `mist`. No faces, no initials. Same alias → same glyph.

---

## 7. Components

Built on shadcn/ui (Radix) and restyled with the tokens above.

| Component | Spec |
|---|---|
| **Button** | Height 44 (mobile) / 40 (desktop), radius `r-control`, label 15/600. *Primary:* `verdant-700` bg, white text, hover `verdant-800`. *Accent:* `ember-500` bg, `ink` text (use for the single most energetic action on a page, e.g. "Request access"). *Secondary:* white bg, `hairline` border, `ink` text. *Ghost:* text only. *Danger:* `danger-600`. Loading: spinner replaces nothing; label stays, width fixed |
| **Input / Textarea / Select** | 44 px height, `hairline` border, focus ring (see §9), label above always visible, helper text 12.5 px, error text `danger-600` with icon, linked via `aria-describedby` |
| **Upload dropzone (video)** | Dashed `hairline` panel; on select shows preview, duration, size, and validation ("3:42. Videos must be 3:10 or shorter. Trim it and upload again."); progress bar `verdant-600` |
| **Tabs** | Underline style, 2 px `verdant-700` active indicator |
| **Data table** | `mist` header row, 14/22 text, row hover `mist`, sticky header, horizontal scroll container on small screens; sortable columns announce state |
| **Candidate card** | `r-panel`, hairline border, shadow-1 on hover. Alias glyph + alias, university category chip, match meter (thin bar `verdant-600` on `mist`) + words ("Strong match · High confidence"), top three verified skill chips with levels, one reason line, actions: *View* (secondary) and *Request access* (accent). Lock row: "Identity hidden until the student agrees" |
| **Access request card** (student) | Organization name + Verified organization chip, role, message, requested data list; actions *Review request* |
| **Consent sheet** | Side sheet (shadow-2): what they asked for, checkboxes per scope with plain descriptions, duration select (7 / 30 / 90 days), *Accept* (primary) and *Decline* (secondary); footnote: "You can withdraw access any time from Sharing." |
| **Audit progress** | Vertical steps with state icons: done (green check), active (ember dot, subtle 1.2 s pulse), waiting (hollow). Live region (`aria-live="polite"`) announces step changes |
| **Skill graph** | Nodes sized by score; *verified* = `verdant-600` fill + check; *in progress* = `ember-500` outline; *not assessed* = dashed hairline. Edges 1 px `#D5DDD8`. Hover/focus highlights neighbours. Always paired with a **list view toggle** for accessibility and mobile |
| **Stat** | Plain figure + label inline, no card (use in a row with hairline dividers) |
| **Toast** | Bottom-centre, 4 s, includes undo where possible; reuses the action's verb ("Request sent") |
| **Dialog** | `r-panel`, shadow-2, focus trapped, Escape closes, primary action right |
| **Skeleton** | `mist` blocks with a slow shimmer (disabled under reduced motion) |
| **Empty state** | Small illustration made of palette circles/arcs on `mesh`, one sentence of direction, one button |

---

## 8. Layout patterns

### 8.1 App shell (portals)

```
┌────────────┬──────────────────────────────────────────────────────┐
│ ◖ AptoHire │  Search…                         🔔   Aarav ▾         │ ← 56px top bar, portal strip behind
│ student    ├──────────────────────────────────────────────────────┤
│            │                                                      │
│ Home       │   Page title (h1)                       [Primary]    │
│ Projects   │   One-line description (moss)                        │
│ Scorecard  │                                                      │
│ Sharing    │   ─────────────────────────────────────────────────  │
│ Profile    │   content (max 1200)                                 │
│            │                                                      │
│ Help       │                                                      │
└────────────┴──────────────────────────────────────────────────────┘
 232px rail (collapses to 72px icons; becomes bottom tab bar on mobile)
```

Nav items per portal:

- **Student:** Home · Projects · Scorecard · Sharing · Profile
- **University:** Overview · Students · Roster · Placements · Skills demand
- **Organization:** Jobs · Candidates · Requests · Pipeline · Directory
- **Admin:** Approvals · Reviews · Tickets · Agent runs · Settings

### 8.2 Marketing hero (root)

```
┌──────────────────────────────────────────────────────────────────────┐
│ AptoHire            How it works   For students   Organizations  Log in│
│                                                                      │
│  Hired for what you can do.            ┌───────────────────────────┐ │
│                                        │      ◯ 72  Proof Ring     │ │
│  Build a real project, get it          │   React · Verified        │ │
│  reviewed in minutes, and carry a      │ ─ Correctness     ▇▇▇▇▇▁  │ │
│  skill scorecard employers can check.  │   [README.md] [Video 1:42]│ │
│                                        │ ─ Code quality    ▇▇▇▇▁▁  │ │
│  [ Start as a student ]  [ I hire ]    │ ─ Communication   ▇▇▇▇▇▁  │ │
│                                        └───────────────────────────┘ │
│   (mesh wash behind; text left-aligned; scorecard is real UI, not a  │
│    screenshot, and plays the ring reveal once on load)               │
└──────────────────────────────────────────────────────────────────────┘
```

Below the hero: **How it works** (a true sequence: Build → Review → Verify → Get found, numbering allowed), then **three audience sections with different layouts** (student: split with scorecard; university: wide table preview; organization: anonymized candidate list preview), a short privacy statement ("Employers see skills, not names, until you say yes"), and a closing call to action.

### 8.3 Student scorecard

```
┌──────────────────────────────────────────────────────────────────────┐
│ Scorecard › React                                    [Download resume]│
│ ┌────────────────────┐   Competent React developer                    │
│ │      ◯  72         │   Reviewed 12 Oct · Confidence high            │
│ │   Verified ✓       │   "Clear component structure and good use of…" │
│ └────────────────────┘                                                │
│ Evidence                                                              │
│  Correctness      ▇▇▇▇▇▇▇▁▁▁ 74   Works as described; one edge case…  │
│                   [Live site] [src/cart.tsx]                          │
│  Code quality     ▇▇▇▇▇▇▁▁▁▁ 66   …                    [src/hooks/…]  │
│  Communication    ▇▇▇▇▇▇▇▇▁▁ 78   …                    [Video 01:42]  │
│ ──────────────────────────────────────────────────────────────────── │
│  Skill graph (list ⇄ graph)                      Next step            │
│  ◉ React ─ ◉ TypeScript ─ ○ Testing              Build a form with… │
│                                                  [Get a project]      │
│  Not happy with this result?  [Raise a ticket]                        │
└──────────────────────────────────────────────────────────────────────┘
```

### 8.4 Organization candidates

```
┌──────────────────────────────────────────────────────────────────────┐
│ Frontend Developer (React)  · Open · 2 openings        [Edit job]     │
│ Required: React · Proficient   TypeScript · Competent                 │
│ ────────────────────────────────────────────────────────────────────  │
│ ┌───────────────────────────────────────────────────────────────┐    │
│ │ ◔◑ Candidate K7F2   Tier 2 · State university   Strong match  │    │
│ │ ▇▇▇▇▇▇▇▇▁▁   React Proficient · TypeScript Competent          │    │
│ │ Verified React at Proficient and 3 reviewed projects.         │    │
│ │ 🔒 Identity hidden until the student agrees  [View] [Request access]│
│ └───────────────────────────────────────────────────────────────┘    │
│ (more candidates…)                                                    │
└──────────────────────────────────────────────────────────────────────┘
```

### 8.5 University overview

A single wide page: a row of plain stats (verified students, active this month, projects reviewed) divided by hairlines; then a **funnel** (Invited → Registered → Submitted → Verified) as a horizontal bar; a **skills table** (skill, verified students, average score, demand from open jobs); and an **Unmatched demand** list (skill, number of jobs, reason counts, never names).

### 8.6 Responsive

| Width | Behaviour |
|---|---|
| ≥ 1280 | Full shell, side sheets open beside content |
| 1024–1279 | Rail collapses to icons |
| 640–1023 | Rail becomes a drawer; tables scroll horizontally inside their container |
| < 640 | Bottom tab bar (4 items + More); sheets become full-screen; scorecard ring 160 px, evidence rows stack; skill graph defaults to list view |

Minimum supported width 360 px. Touch targets ≥ 44 px.

---

## 9. Accessibility

- **Contrast** per §2.2; colour is never the only signal (icons and words accompany green/orange states).
- **Focus:** visible 2 px `verdant-700` outline, 2 px offset, plus a 4 px white halo to separate it from tinted surfaces. Never remove outlines.
- **Keyboard:** every interactive element reachable and operable; dialogs and sheets trap focus; skill graph nodes focusable with arrow-key navigation; skip-to-content link.
- **Forms:** labels always visible, errors announced (`aria-live`), required fields marked in words.
- **Motion:** reduced-motion removes the ring reveal, pulse, and shimmer; final states render instantly.
- **Media:** videos have captions where available; the audit's transcript is viewable as text.
- **Language:** plain, short sentences; avoid idioms for second-language readers.
- Automated axe checks in CI; manual keyboard pass before each demo.

---

## 10. Voice, copy, and states

**Voice:** plain, warm, specific. Sentence case. Active verbs. No hype words ("revolutionary", "AI-powered" as a headline). Say what happened, not how the system works.

**Vocabulary (use consistently):** *Project · Submit · Review · Scorecard · Verified · Evidence · Request access · Accept · Decline · Sharing · Withdraw access.* Avoid "audit engine", "agent", "pipeline" in student-facing UI.

| Moment | Copy |
|---|---|
| Submit button | Submit project |
| After submit | Project submitted. We're reviewing it now. |
| Audit steps | Reading your code and files · Watching your demo video · Scoring against the rubric · Writing your feedback |
| Score ready | Your React score is ready. |
| Verified | You're verified in React at the Competent level. |
| Not verified | Not verified yet. You're 9 points away. Here's what to improve. |
| Borderline | Under human review. A reviewer will confirm your result within 3 working days. |
| Video too long | This video is 3:42. Videos must be 3:10 or shorter. Trim it and upload again. |
| Candidate lock | Identity hidden until the student agrees. |
| Request sent | Request sent. You'll see it here when the student responds. |
| Access request (student) | Northwind Labs would like to see your profile and scorecard for 30 days. |
| Accept | Accept request · *toast:* Access shared until 12 Nov. |
| Withdraw | Withdraw access · *toast:* Access withdrawn. |
| Unverified university | Your university isn't on AptoHire yet. Your scores and job matches are not affected. |
| Placement unknown | Unknown. Add placement details to complete this record. |

**Empty states** (one sentence of direction + one action):

- Student, no projects: "No projects yet. Pick a skill and get your first project." → *Get a project*
- Organization, no candidates: "No verified candidates match yet. Try lowering a required level or adding related skills." → *Edit job*
- University, no roster: "Add your students to get started. Upload a CSV with name, email, and year." → *Upload roster*
- Student, no requests: "No requests yet. When an organization asks to see your profile, it will appear here."

**Errors** state what happened and the fix; they don't apologize: "We couldn't finish the review. Retry now, or contact support if it happens again." Loading uses skeletons that match the final layout; long waits (audit) show the progress steps, not a spinner.

---

## 11. Asset notes

- **Logo:** wordmark "AptoHire" in Bricolage 700 with a small seal mark (a circle with a check whose stroke ends in an orange dot). Provide SVG on white and on `verdant-700`.
- **Icons:** Lucide, 1.75 px stroke, 20 px default.
- **Illustrations:** built from palette circles/arcs; no stock photography of people.
- **Favicon:** the seal mark on white.
- **Open Graph image:** hero scorecard composition on `mesh`.

---

## 12. Design acceptance checklist

- [ ] One gradient surface per viewport at most; none on buttons or body text blocks
- [ ] Primary labels pass contrast (white on `verdant-700`; `ink` on `ember-500`)
- [ ] Proof Ring renders all four states (verified, not verified, under review, loading)
- [ ] Every score is paired with openable evidence
- [ ] Candidate views show **no** name, photo, university name, or file links before consent
- [ ] Works at 360 px; tables scroll inside their container; skill graph has a list view
- [ ] Reduced-motion tested; keyboard-only run of the demo script succeeds
- [ ] Copy uses the vocabulary in §10; no tracked all-caps labels; sentence case throughout
