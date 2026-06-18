# Mom Test Validation Plan

## Input Idea

Validate two threads from [`context/team/opportunity-map.md`](opportunity-map.md) before building post-MVP product work or implementing the ranked internal refactor (TD-2):

1. **Product (P-1, P-2, P-3):** Engineers paste multi-source prod logs into generic AI tools (secret exposure), correlate signals manually, and cannot append sources after case creation in SafeLog MVP.
2. **Internal (I-1, I-2):** The intake persist seam (`findings` hash → `create!`) lacks a typed contract; `ProcessCaseSubmission` has untested rollback paths and mixed responsibilities.

**Recommended first candidate from opportunity map:** I-1 (TD-2 finding persist contract).

---

## Hypotheses

### Thread A — Product (post-MVP)

- **User/role:** Solo backend/support engineer debugging SaaS-style production incidents (primary persona from PRD); optionally on-call engineers at small teams.
- **Friction:** (P-1) Raw secrets reach AI chat when pasting logs under time pressure; (P-2) cross-source correlation is slow without a joined view; (P-3) new log lines after triage force re-work because MVP requires one-shot submission.
- **Current workaround:** Paste into ChatGPT/Claude with manual redaction; tab-switch across CloudWatch/Rails/APM/browser; re-create cases or work outside SafeLog until all sources are ready.
- **Proposed solution:** SafeLog MVP (already built) plus post-MVP features: pre-paste gate, richer correlation, append-sources flow.
- **Risky assumptions:**
  - Engineers actually paste raw prod logs into AI today (not just "would" in a demo).
  - SafeLog is too slow or awkward to adopt during a real incident (bypass risk).
  - Append-sources is essential pain, not an MVP simplification that real users accept.
  - Correlation in SafeLog is materially better than manual + generic AI for the persona.
- **Evidence already present:**
  - Shape-notes articulate the pain category (security/compliance + manual correlation) — **assumed, not interviewed**.
  - MVP shipped and demo case exists — **proves buildability, not adoption**.
  - PRD parked append-sources and live integrations — **intentional scope cut, not validated deferral**.
  - **No** support tickets, incident postmortems, or user interviews in repo.

### Thread B — Internal (TD-2 / intake safety)

- **User/role:** Maintainer extending intake, redaction, or findings (course operator + future contributors).
- **Friction:** Implicit 4-key hash contract at persist seam; inner-loop rollback untested; monolithic orchestrator slows safe refactors.
- **Current workaround:** `bin/ci` + security oracles + careful manual review of `ProcessCaseSubmission`; refactor research ranked TD-2 #1.
- **Proposed solution:** Contract spec + `RedactionFinding.build_from_engine_finding`; then rollback specs (G-01/G-02).
- **Risky assumptions:**
  - The implicit contract has caused or will cause real rework (not just theoretical debt).
  - A factory at the seam is the cheapest guard, vs more engine specs alone.
  - Architect certification timeline requires this refactor now, not later.
- **Evidence already present:**
  - `refactor-opportunities/research.md`: ast-grep verified sole `create!` call-site, zero mapper, 4-key hash — **strong structural evidence**.
  - 15 test gaps documented (G-01–G-15) — **documented risk, not a triggered incident**.
  - Five commits touched `process_case_submission.rb` post-MVP — **some churn, no recorded production failure**.
  - **No** logged near-miss where a hash key rename broke persist undetected until runtime.

---

## Critique

### Where solution is confused with problem

- **P-1** names "pre-paste secret scanner" as complement — that is a solution. The problem is only validated if someone **recently pasted prod logs into AI** and either leaked a secret or spent non-trivial time redacting first.
- **P-2** assumes SafeLog's correlation is the unmet need; the MVP **already** correlates via placeholders and signals. Post-MVP work needs evidence that demo-case correlation is **insufficient** vs the user's current ChatGPT + tabs workflow — not that correlation is "nice."
- **P-3** treats "can't append sources" as friction; PRD explicitly chose one-shot submission for speed. That may be **essential complexity** (atomic case snapshot) rather than accidental pain — mom-test must distinguish "I re-created a case" (behavior) from "I wish I could append" (hypothetical).

### Thin evidence, polished PRD

Shape-notes and PRD read like a well-reasoned **synthetic persona** (course project operator). There are zero past-behavior interviews, tickets, or incident artifacts in the repo. **Product thread fails Mom Test on evidence today** — the problem category is plausible but not proven.

Internal thread is stronger on **structural facts** (verified call-sites, test gaps) but weaker on **experienced pain** — no maintainer has reported a near-miss from the implicit contract.

### What would prove "not worth building"

**Product:**

- Interviewee last three incidents used observability vendor AI features or internal runbooks — never pasted raw logs into ChatGPT.
- SafeLog demo flow takes less time than their habitual workaround, but they still wouldn't use it under pressure (trust, login, paste friction).
- Append-sources never came up unprompted; one-shot submission matches how they actually gather logs (all at once before analysis).

**Internal:**

- No planned intake/findings changes in next 4 weeks; MVP stable.
- `bin/ci` + existing engine specs already caught every contract drift attempt (none occurred).
- Architect badge does not require TD-2 implementation (only exploration) — refactor is optional hygiene.

### Existing alternatives "good enough"

- **Product:** Generic AI + manual redaction; vendor-native "explain this trace" in Datadog/New Relic; copying sanitized excerpts only; not using AI during incidents.
- **Internal:** Current security oracles + `engine_spec` hash shape checks; document the 4-key contract in repo-map; defer mapper until next findings column.

### Strong evidence to proceed

**Product (post-MVP feature):** ≥2 of 3 interviewees describe a **specific recent incident** (last 90 days) where they pasted multi-source logs into AI **or** re-assembled a case because sources arrived late — without being asked about SafeLog.

**Internal (TD-2):** Maintainer can point to a **concrete change** (planned or attempted) where findings shape mattered, **or** Architect path requires implemented refactor with deadline; contract spec is ≤1 day and unblocks ranked work.

---

## Clarifying Questions (for you, before interviews)

Answer these yourself first — they calibrate whether peer interviews are worth scheduling:

1. **Last real incident:** Walk through the last time you debugged a multi-source prod issue. Did you paste into ChatGPT/Claude? Did you use SafeLog? What took the most time?
2. **Append-sources:** In that incident, did log lines arrive **after** your first analysis pass? What did you actually do?
3. **TD-2:** When you read `refactor-opportunities/research.md`, did you feel blocked or anxious about touching `ProcessCaseSubmission`, or is TD-2 "good hygiene" for certification?

---

## Bad Questions → Rewrites

```text
Instead of:
"Would you use SafeLog instead of ChatGPT for debugging?"

Ask:
"Walk me through the last production issue where you used AI — what did you paste, and where did it come from?"

Why:
Reveals actual behavior and data sources, not approval of SafeLog.
```

```text
Instead of:
"Is cross-source correlation a pain point for you?"

Ask:
"The last time you matched a request ID across two log systems — what tools were open, and how long did it take?"

Why:
Surfaces real coordination cost and workarounds.
```

```text
Instead of:
"Would append-sources be a useful feature?"

Ask:
"The last time new logs arrived after you started triaging — did you restart your analysis? What did that restart look like?"

Why:
Tests whether append is real rework or a hypothetical nice-to-have.
```

```text
Instead of:
"Do you think we need a typed contract for redaction findings?"

Ask:
"The last time you changed intake or redaction code — what did you run to feel confident before merge? Was anything hard to test?"

Why:
Surfaces maintainer behavior and test rituals, not architecture preferences.
```

```text
Instead of:
"How much would you pay for safe log analysis?"

Ask:
"What happened the last time sensitive data might have left your environment during debugging?"

Why:
Pricing fantasy; compliance/risk events are behavioral evidence.
```

---

## Interview Guide (~25 min)

**Audience:** Backend/on-call engineers who debug production issues (include yourself as Thread A; a maintainer/contributor for Thread B). Minimum 2 peers if available; self-interview acceptable for course context but **does not satisfy** product Proceed thresholds alone.

### 1. Context warm-up (3 min)

1. What is your role when production issues land, and how often does that happen?
2. When an customer-reported bug hits prod, what is usually your first three steps?

*Follow-up:* Do you reach for AI in the first hour, or only after manual digging?

### 2. Recent story — AI + logs (7 min)

3. **Tell me about the last incident where you considered using AI on log output.** What triggered it?
4. What log sources did you have (app, infra, APM, browser, customer message)? Where did you view each?
5. What text actually went into the AI tool — raw paste, edited paste, or nothing? Why that choice?

*Follow-up:* Did anyone redact or warn about secrets? How long did that take?

### 3. Current workaround — correlation (5 min)

6. **The last time you needed the same request ID in two different systems** — walk me through it step by step.
7. What would have gone wrong if you missed the link between sources?

*Follow-up:* Did you keep a personal doc, Slack thread, or ticket as the "source of truth"?

### 4. Late-arriving evidence (5 min)

8. **Think of the last incident where new logs or traces appeared after you started analysis.** What did you do with your partial notes or earlier AI conversation?
9. Did you ever re-submit or re-paste the full bundle because something was missing?

*Follow-up:* How much time did that re-work cost?

### 5. SafeLog / similar tools (3 min)

10. Have you used SafeLog, an internal redaction tool, or a ticket-attached log bundle? **When was the last time — what happened?**
11. If you haven't used it in a real incident, what would need to be true for you to reach for it during the next one?

*Do not demo SafeLog mid-interview unless they ask — biases toward politeness.*

### 6. Maintainer thread — intake/refactor (optional, 5 min)

12. **The last time you changed code on the intake or redaction path** — how did you verify nothing raw leaked and nothing broke persist?
13. Was there a change you avoided because the intake service felt risky to touch?

*Follow-up:* Did a test fail or a review comment catch a shape mismatch between engine output and DB?

### 7. Closing (2 min)

14. Can I follow up after you next real incident? Any anonymized export (ticket, Slack redacted thread) you could share?

---

## Survey (6–10 questions, async broader signal)

**Screener:**

1. In the last 90 days, have you debugged a production or staging issue using logs from **more than one system** (e.g. app + infra/APM)?
   - [ ] Yes, multiple times
   - [ ] Yes, once
   - [ ] No → **thank and exit**

**Frequency & behavior:**

2. How often do you paste log excerpts into a generic AI chat (ChatGPT, Claude, Copilot chat) while debugging?
   - [ ] Weekly or more
   - [ ] Monthly
   - [ ] Rarely / never in last 90 days

3. The last time you pasted logs into AI, how did you handle secrets (tokens, emails, IDs)?
   - [ ] Pasted raw — didn't think about it
   - [ ] Manual find-and-delete/redact before paste
   - [ ] Used only sanitized/exported excerpts
   - [ ] Didn't paste logs to AI

4. When matching IDs or timestamps across sources, typical effort:
   - [ ] Under 5 minutes
   - [ ] 5–20 minutes
   - [ ] 20+ minutes
   - [ ] Didn't need cross-source matching

5. In the last 90 days, new log lines arrived **after** you started triage:
   - [ ] Yes — restarted or duplicated my analysis
   - [ ] Yes — worked around without restarting
   - [ ] No / doesn't apply

**Open (recent example):**

6. **Briefly describe the last multi-source debugging session** (no customer names, no raw secrets): what systems, what slowed you down most?

7. (Maintainers only) **Last change to intake/redaction/persist path:** what did you run before merge, and did anything feel untested?

**Not included:** solution approval, feature ranking, pricing, NPS.

---

## Decision Criteria

### Thread A — Product (P-1, P-2, P-3)

- **Proceed to `/10x-shape` for post-MVP feature** if:
  - ≥2 of 3 interviewees (excluding self) describe unprompted recent behavior matching P-1 **or** P-3 in the last 90 days; **and**
  - ≥1 describes measurable cost (time, rework, or compliance near-miss), not mild annoyance; **and**
  - They still use a workaround today (ChatGPT paste, re-create case, manual correlation).

- **Narrow scope** if:
  - P-1 (secret exposure) is real but they won't adopt a new app mid-incident → shape **pre-paste CLI / editor integration**, not full case workflow.
  - P-2 only: correlation pain is real but AI+tabs is "good enough" → extend correlation in SafeLog only, don't build new surface.
  - P-3 only: append pain appears once but one-shot fits their habit → document workaround, park append.

- **Do not build yet** if:
  - ≤1 interviewee has relevant recent behavior; or
  - All describe vendor AI or runbooks as sufficient; or
  - SafeLog MVP unused in real incidents and no blocker articulated except "didn't think of it."

- **Try existing tool/process first** if:
  - They already use observability vendor AI on exported traces; or
  - Team policy forbids external AI — problem is policy/training, not missing product.

### Thread B — Internal (I-1 TD-2, I-2 rollback specs)

- **Proceed to `/10x-new` → plan → implement TD-2** if:
  - Architect certification requires **implemented** refactor (not just research); **or**
  - You plan intake/findings changes within 4 weeks; **or**
  - Self-interview Q3: touching `ProcessCaseSubmission` feels risky **and** rollback/contract gaps are why.

- **Narrow scope** if:
  - Proceed with **contract spec + factory only** (TD-2), bundle I-2 rollback specs in same change; defer IMPL-1 extraction.

- **Do not build yet** if:
  - MVP stable, no intake changes planned, certification does not require implementation; **try** documenting 4-key contract in repo-map first.

- **Try existing process first** if:
  - `bin/ci` + adding one engine contract example suffices for confidence; mapper is optional until second findings field.

### Combined recommendation (pre-interview)

| Thread | Pre-interview verdict | Rationale |
|--------|----------------------|-----------|
| **Product post-MVP** | **Do not build yet** (until interviews) | Plausible pain, zero behavioral evidence in repo |
| **Internal TD-2** | **Narrow scope → likely proceed** | Structural evidence strong; low-cost, mock-data, unblocks Architect; not dependent on user interviews |

**Suggested order:** Run self-reflection (3 clarifying questions) → 2 peer interviews if available → implement TD-2 if Architect timeline pressures → product `/10x-shape` only if product Proceed criteria met.

---

## Next Step

After completing self-reflection or interviews, update the **Evidence already present** bullets in this file with quotes/dates.

- Product Proceed met → **`/10x-shape`** for winning signal (append, correlation, or pre-paste).
- Internal Proceed met → **`/10x-new`** → **`/10x-plan`** → **`/10x-implement`** for TD-2 (+ G-01/G-02).
- Mixed → narrow per criteria above.
