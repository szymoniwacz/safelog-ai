# Quality Gates Alignment — Implementation Plan

## Overview

Rollout Phase 3 of `context/foundation/test-plan.md`: **document and align** local `bin/ci` with GitHub Actions — gate coverage, command flags, encryption env bootstrap, and contributor commands. Research confirmed all gates run in both paths; the actionable gap is **Brakeman flag mismatch** plus missing gate cookbook prose. No new RSpec examples (122 baseline unchanged).

## Current State Analysis

Research (`context/changes/testing-quality-gates-alignment/research.md`) verified:

- **Local pipeline** — sequential `config/ci.rb`: setup → RuboCop → bundler-audit → importmap audit → Brakeman (strict flags) → RSpec.
- **GHA pipeline** — four parallel jobs in `.github/workflows/ci.yml`; same gates, but Brakeman runs with `--no-pager` only (no `--exit-on-warn --exit-on-error`).
- **Encryption** — GHA `test` job sets CITest* `RAILS_ACTIVE_RECORD_ENCRYPTION_*` vars; local test uses credentials via `master.key` unless ENV set (`config/environments/test.rb:54-60`).
- **Docs drift** — `AGENTS.md:32` still says "116+ examples"; test-plan §5 says 122; §6 has no gate cookbook (§6.7 TBD).

### Key Discoveries

- `config/ci.rb` is the source of truth for Brakeman strictness — GHA should mirror, not weaken.
- RuboCop `-f github` in GHA is annotation-only; no local change needed.
- mise wrapper is local-only per AGENTS.md; GHA uses `ruby/setup-ruby` — document, don't unify.

## Desired End State

1. GHA `scan_ruby` Brakeman invocation matches `config/ci.rb` flags.
2. `context/foundation/test-plan.md` §6.7 documents gate parity (local vs GHA matrix, mise, encryption paths, individual vs full CI).
3. §6.6 records Phase 3 completion; §3 Phase 3 status → `complete`.
4. `AGENTS.md` example count updated to 122 and references gate cookbook.
5. `mise exec -- bin/ci` and GHA CI remain green; example count unchanged at 122.

### Verification

```bash
mise exec -- bin/ci
# Optional: confirm Brakeman step flags match between config/ci.rb and .github/workflows/ci.yml
```

## What We're NOT Doing

- New RSpec examples or test-plan example count change.
- Consolidating GHA jobs into a single job (parallelism is intentional).
- Adding RuboCop `-f github` to local `config/ci.rb`.
- Post-edit hooks, Playwright, auto-deploy, parity diff scripts.
- Rewriting README beyond optional `bin/*` wrapper alignment (minimal if touched).

## Implementation Approach

Two phases: **fix the one real parity gap first** (Brakeman flags), then **document everything else** in test-plan §6.7 and refresh AGENTS.md. Verify with full `bin/ci` after Phase 1; re-run after Phase 2 if any workflow/doc edits could affect CI (they should not).

## Critical Implementation Details

**Brakeman alignment:** Update the GHA `scan_ruby` step to invoke the same flags as `config/ci.rb:10`: `--quiet --no-pager --exit-on-warn --exit-on-error`. `bin/brakeman` still prepends `--ensure-latest` in both environments.

**§6.7 content:** Include explicit parity table (gate | local command | GHA job/step | notes), encryption dual-path (credentials vs CITest* ENV), and `mise exec -- bin/ci` as the pre-push command. Cross-reference §5 gate list — do not duplicate the full risk map.

## Phase 1: Brakeman Parity Fix

### Overview

Align GHA Brakeman with local `config/ci.rb` so warnings fail in both environments.

### Changes Required

#### 1. GitHub Actions Brakeman step

**File**: `.github/workflows/ci.yml`

**Intent**: Match Brakeman flags used in `config/ci.rb` so GHA does not pass when local `bin/ci` would fail on Brakeman warnings.

**Contract**: Change `scan_ruby` Brakeman `run:` line from `bin/brakeman --no-pager` to `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` (same string as `config/ci.rb:10` after the `bin/brakeman` prefix).

### Success Criteria

#### Automated Verification

- `mise exec -- bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` passes locally.
- `mise exec -- bin/ci` passes.

#### Manual Verification

- Diff `config/ci.rb` Brakeman step against `.github/workflows/ci.yml` `scan_ruby` Brakeman step — flags identical.

---

## Phase 2: Gate Cookbook + Contributor Doc Refresh

### Overview

Ship test-plan §6.7 gate cookbook, §6.6 Phase 3 notes, and AGENTS.md refresh. Mark test-plan §3 Phase 3 complete.

### Changes Required

#### 1. Add §6.7 gate parity cookbook

**File**: `context/foundation/test-plan.md`

**Intent**: Replace the Phase 3 TBD at §5 line 111 with a durable cookbook subsection.

**Contract**: New `### 6.7 Running and aligning quality gates` covering:

- When to run `mise exec -- bin/ci` vs individual `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`, `bin/importmap audit`, `bundle exec rspec`.
- Local sequential pipeline (`config/ci.rb`) vs GHA four-job layout (table: gate → local step → GHA job).
- Brakeman / RuboCop flag notes (strict Brakeman aligned; `-f github` GHA-only).
- Encryption: GHA CITest* env vars vs local `master.key` / credentials (`config/environments/test.rb`, README).
- Optional one-liner for exporting CITest* vars locally when `master.key` absent (copy values from `ci.yml` test job — not production secrets).
- **Run:** `mise exec -- bin/ci`

#### 2. Update §6.6 Phase 3 entry and §3 status

**File**: `context/foundation/test-plan.md`

**Intent**: Close Phase 3 rollout in the test plan artifact.

**Contract**:

- §6.6 append Phase 3 entry: change-id, date, files touched (`.github/workflows/ci.yml`, `AGENTS.md`, test-plan §6.7), no example count delta (122 unchanged), deferrals (GHA job consolidation, automated parity script, RuboCop formatter unification).
- §3 Phase 3 Status → `complete`.
- §5 line 111 Phase 3 note can be trimmed or point to §6.7 (implementer choice — avoid duplicate prose).

#### 3. Refresh AGENTS.md

**File**: `AGENTS.md`

**Intent**: Fix stale example count and point agents at gate cookbook.

**Contract**:

- Line ~32: `116+ examples` → `122 examples`.
- Add brief pointer to `context/foundation/test-plan.md` §6.7 for gate parity (one clause in Commands or RSpec paragraph — minimal).

#### 4. Optional README wrapper alignment

**File**: `README.md`

**Intent**: Individual gate examples use `bin/rubocop` / `bin/brakeman` instead of bare `bundle exec` — only if implementer touches README during doc pass; skip if out of scope for minimal diff.

**Contract**: Quality gates section commands match `bin/*` wrappers used in `bin/ci`.

### Success Criteria

#### Automated Verification

- `mise exec -- bin/ci` passes (no test changes expected).

#### Manual Verification

- §6.7 is self-contained for a contributor verifying local vs GHA parity before push.
- AGENTS.md example count matches `bundle exec rspec spec/ --dry-run | tail -1`.

---

## Testing Strategy

No new specs. Verification is `bin/ci` green before and after. Phase 1 Brakeman alignment may surface existing Brakeman warnings on GHA — if so, fix warnings or document why (prefer fix if trivial).

## Performance Considerations

None.

## Migration Notes

None.

## References

- Research: `context/changes/testing-quality-gates-alignment/research.md`
- Test plan: `context/foundation/test-plan.md` §3, §5, §6
- Local CI: `config/ci.rb`
- GHA: `.github/workflows/ci.yml`
- Phase 2 archive: `context/archive/2026-06-01-testing-critical-http-path-regression/plan.md`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands.

### Phase 1: Brakeman Parity Fix

#### Automated

- [ ] 1.1 `mise exec -- bin/ci` passes after GHA Brakeman flag alignment

#### Manual

- [ ] 1.2 Brakeman flags in `config/ci.rb` and `.github/workflows/ci.yml` match

### Phase 2: Gate Cookbook + Contributor Doc Refresh

#### Automated

- [ ] 2.1 `mise exec -- bin/ci` passes after documentation edits

#### Manual

- [ ] 2.2 §6.7 and §6.6 Phase 3 entry complete; §3 Phase 3 marked complete; AGENTS.md shows 122 examples
