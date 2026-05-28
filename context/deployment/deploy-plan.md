# SafeLog AI — First Fly.io Deployment Plan

## Scope

Deploy the **full MVP** (F-01–S-06) to Fly.io as a **public course demo** using:

- Docker image from [`Dockerfile`](../../Dockerfile)
- SQLite files on a Fly Volume mounted at `/rails/storage`
- Single Machine in **`fra`** (Frankfurt), `min_machines_running = 1`
- Devise auth, encrypted diagnostic schema, safe intake, analyze, export, archive
- **Manual** `fly deploy` (no GitHub Actions deploy workflow yet — per [`context/foundation/infrastructure.md`](../foundation/infrastructure.md))

**Out of scope for this deploy:** CI auto-deploy, staging app, Postgres, Redis, LiteFS, backups automation, custom domain/DNS.

```mermaid
flowchart LR
  dev[Local_mise_dev] --> build[fly_deploy_Docker_build]
  build --> machine[Single_Fly_Machine_fra]
  machine --> volume["Volume_data_/rails/storage"]
  volume --> sqlite["storage/production*.sqlite3"]
  machine --> publicURL["https://safelog-ai.fly.dev/"]
```

---

## Preconditions (before any Fly commands)

| Check | Why |
|-------|-----|
| Local app boots | `mise exec -- bin/rails db:prepare` succeeds; SQLite under `storage/` |
| CI gates pass | `mise exec -- bin/ci` green (RuboCop, Brakeman, bundler-audit) |
| `config/master.key` exists locally | Required for `RAILS_MASTER_KEY` secret (gitignored; never commit) |
| Fly account + billing | No permanent free tier; expect ~$6–8/mo always-on |
| `flyctl` installed on host | **Not** via mise — host-only tool |

---

## Files to check or change

### Must change (before first deploy)

| File | Current state | Required change |
|------|---------------|-----------------|
| [`fly.toml`](../../fly.toml) | `primary_region = "fra"`, `min_machines_running = 1` | ✅ Applied — verify before deploy |
| [`config/environments/production.rb`](../../config/environments/production.rb) | `config.hosts`, SSL, AR encryption env | ✅ Applied — verify |

### Verify (likely OK; fix only if deploy fails)

| File | What to verify |
|------|----------------|
| [`fly.toml`](../../fly.toml) | `[mounts] source = "data"` → `destination = "/rails/storage"` matches [`config/database.yml`](../../config/database.yml) paths (`storage/*.sqlite3` → `/rails/storage/*.sqlite3`) |
| [`fly.toml`](../../fly.toml) | `internal_port = 8080` + `[env] PORT = "8080"` align with Puma (`config/puma.rb` reads `ENV["PORT"]`) and Thruster CMD |
| [`bin/docker-entrypoint`](../../bin/docker-entrypoint) | Runs `db:prepare` before server — args `./bin/thrust ./bin/rails server` still match `${@: -2:1}` / `${@: -1:1}` check |
| [`Dockerfile`](../../Dockerfile) | Ruby `3.4.9`, `sqlite3`/`libsqlite3-dev`, no mise; production bundle path is image-local (`/usr/local/bundle`) — separate from dev `vendor/bundle` |
| [`.dockerignore`](../../.dockerignore) | Excludes `config/master.key`, local `storage/*.sqlite3` (correct — DB created on volume at boot) |
| [`config/environments/production.rb`](../../config/environments/production.rb) | `safelog-ai.fly.dev` in hosts; SSL; AR encryption from Fly env |
| [`db/schema.rb`](../../db/schema.rb) | Full MVP schema — `db:prepare` on boot creates/migrates on volume |

### Optional follow-ups (not blocking shell deploy)

| File | Note |
|------|------|
| [`.dockerignore`](../../.dockerignore) | `/vendor/bundle` excluded | ✅ Applied |
| [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) | Add deploy workflow later; not part of first manual deploy |
| [`context/foundation/tech-stack.md`](../foundation/tech-stack.md) | Still says SQLite migration is “planned” — doc sync only |

### Do not change for this deploy

- Local `.bundle/config` / `vendor/bundle` setup
- Dockerfile production `BUNDLE_PATH` (intentionally different from local dev)

---

## Required Fly.io setup (first-time — app not created)

**Use `fly apps create` + `fly deploy`, not `fly launch`** — `fly launch` can overwrite existing [`fly.toml`](../../fly.toml).

### 1. Install and authenticate

```bash
# macOS
brew install flyctl
# or: curl -L https://fly.io/install.sh | sh

fly auth login
fly orgs list   # note your org slug (often personal)
```

### 2. Create the app (manual — you must do this)

```bash
fly apps create safelog-ai --org personal
```

Replace `personal` with your org if different. Confirm name is free; if taken, pick e.g. `safelog-ai-demo` and update `app = "..."` in `fly.toml`.

### 3. Create persistent volume (same region as `primary_region`)

Volume name **must** match `[mounts] source`:

```bash
fly volumes create data --region fra --size 1 --app safelog-ai
```

- **1 GB** is enough for MVP demo SQLite + Active Storage
- Volume is **single-region**, **single-Machine** — no horizontal scale without LiteFS/Postgres

### 4. Set secrets

#### Required now (shell deploy)

```bash
fly secrets set RAILS_MASTER_KEY="$(cat config/master.key)" --app safelog-ai
```

Rails 8 derives `SECRET_KEY_BASE` from credentials via `RAILS_MASTER_KEY` — no separate `SECRET_KEY_BASE` secret needed if credentials are configured.

#### Required before first MVP deploy (not just `/up`)

```bash
fly secrets set RAILS_MASTER_KEY="$(cat config/master.key)" --app safelog-ai

# Required — encrypted diagnostic fields fail without these:
fly secrets set \
  RAILS_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY="..." \
  RAILS_ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY="..." \
  RAILS_ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT="..." \
  --app safelog-ai
```

Generate encryption keys locally:

```bash
mise exec -- bin/rails db:encryption:init
```

#### Optional — real AI analyze (otherwise FakeClient + UI notice)

```bash
fly secrets set OPENAI_API_KEY="..." --app safelog-ai
```

#### Previously shell-only (now superseded)

```bash
# OPENAI_API_KEY and AR encryption were listed as "before product features"
# — both are required for a working MVP demo with persisted cases.
```

#### Not needed for SQLite MVP

- `DATABASE_URL` — file SQLite on volume only

---

## SQLite volume setup (how it works)

| Layer | Path |
|-------|------|
| Fly mount | `destination = "/rails/storage"` |
| Rails production DBs | `storage/production.sqlite3`, `production_cache.sqlite3`, `production_queue.sqlite3`, `production_cable.sqlite3` |
| Boot behavior | [`bin/docker-entrypoint`](../../bin/docker-entrypoint) → `db:prepare` creates/migrates DB files on the volume |

**Important Fly constraints:**

- `release_command` **cannot** access the volume — migrations must run at **container boot** (already handled by entrypoint)
- Ephemeral container FS is wiped on deploy; only `/rails/storage` persists
- No automated backups in MVP — accept demo data loss risk

---

## Exact command sequence (after config fixes)

Run from repo root. **Do not use `mise exec` for Fly commands** — flyctl is host-only.

```bash
# 0. fly.toml edits applied (fra region, min_machines_running = 1)

# 1. Pre-flight local
mise exec -- bin/ci

# 2. Fly one-time setup (manual)
fly auth login
fly apps create safelog-ai --org personal
fly volumes create data --region fra --size 1 --app safelog-ai
fly secrets set RAILS_MASTER_KEY="$(cat config/master.key)" --app safelog-ai

# 3. Deploy
fly deploy --app safelog-ai

# 4. Post-deploy verification (below)
```

Subsequent deploys:

```bash
fly deploy --app safelog-ai
fly logs --app safelog-ai
```

---

## Manual steps you must do (cannot be automated by agent alone)

1. **Create Fly.io account** and add a payment method (trial is limited; demo needs paid always-on if `min_machines_running = 1`)
2. **Install `flyctl`** on your Mac and run `fly auth login`
3. **Create app** — `fly apps create safelog-ai` (pick org; resolve name collision if needed)
4. **Create volume** in `fra` — must happen **before** first deploy that references `[mounts]`
5. **Copy `RAILS_MASTER_KEY`** from local `config/master.key` into Fly secrets (you hold the key; agent must never commit it)
6. **Run first `fly deploy`** and watch build logs for Docker/Ruby errors
7. **Open public URL** in browser — confirm demo is reachable
8. **Optional demo week:** accept ~$6–8/mo for `min_machines_running = 1`; scale to `0` later to save cost at the cost of cold starts

---

## Verification steps after deploy

### Automated / CLI

```bash
fly status --app safelog-ai
fly checks list --app safelog-ai          # if available on your flyctl version
fly logs --app safelog-ai --no-tail

curl -sf "https://safelog-ai.fly.dev/up" && echo "OK"
# Expect HTTP 200

fly ssh console --app safelog-ai -C "ls -la /rails/storage"
# Expect production*.sqlite3 files after first boot

fly ssh console --app safelog-ai -C "bin/rails runner 'puts ActiveRecord::Base.connection.adapter_name'"
# Expect: SQLite
```

### Browser / functional

- Visit `https://safelog-ai.fly.dev/` — sign up / sign in; dashboard loads
- Create a case, analyze (demo AI notice if no `OPENAI_API_KEY`), export report
- Visit `https://safelog-ai.fly.dev/up` — health check 200
- Fly dashboard: Machine **started**, volume **attached**, health check **passing**

### Failure triage quick reference

| Symptom | Likely fix |
|---------|------------|
| Region error / cannot deploy to `waw` | Change `primary_region` to `fra` |
| Volume mount failed | Create `data` volume in same region as app |
| Health check failing | Check `fly logs`; verify PORT 8080; check Thruster/Puma binding |
| 403 / blocked host | Add `safelog-ai.fly.dev` to `config.hosts` in production.rb |
| DB missing after deploy | Confirm entrypoint runs `db:prepare`; SSH and inspect `/rails/storage` |
| Missing credentials | Set `RAILS_MASTER_KEY` secret; redeploy |

---

## Risks and MVP trade-offs (accepted)

| Risk | Impact | Mitigation for demo |
|------|--------|---------------------|
| Single Machine + SQLite | No HA; write contention if traffic grows | MVP/demo only; Postgres later |
| Volume tied to one Machine | Cannot `fly scale count 2` without LiteFS | Keep `count = 1` |
| No backup strategy | Demo data loss on corruption/bad migration | Manual `fly ssh` + file copy before risky migrations |
| `min_machines_running = 0` | Cold starts break live demos | Use `1` for demo period |
| Deprecated `waw` region | Deploy failure | Use `fra` |
| Public URL with Devise auth | Unauthenticated users see sign-in only; register open for course demo | Accept for course demo; restrict registration later if needed |
| AR Encryption keys required | App boot may fail or diagnostic writes error without Fly encryption secrets | Set all three `RAILS_ACTIVE_RECORD_ENCRYPTION_*` before demo |
| Manual deploy only | Drift between local and prod until CI deploy added | Document deploy commands; add GH Action later |
| Estimated cost ~$6–8/mo | Not zero-cost | Budget for course demo window |

---

## Suggested execution order

```mermaid
flowchart TD
  approve[Approve_plan] --> writeDoc[Write_deploy-plan.md]
  writeDoc --> editFly[Edit_fly.toml]
  editFly --> localCI[mise_exec_bin_ci]
  localCI --> flySetup[You: fly_apps_create_volume_secrets]
  flySetup --> deploy[You: fly_deploy]
  deploy --> verify[curl_up_SSH_storage_logs]
```
