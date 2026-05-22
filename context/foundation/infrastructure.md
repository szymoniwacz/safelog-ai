---
project: safelog-ai
recommended_platform: Fly.io
context_type: mvp-demo
stack:
  language: ruby
  framework: Rails 8
  runtime: Docker + Puma
  database: SQLite
---

# Infrastructure Decision — SafeLog AI

## Recommendation

SafeLog AI will use:

- Fly.io
- single Rails app instance
- SQLite on persistent Fly volume
- Docker-based deployment

This is an intentional MVP/demo setup focused on:

- low cost,
- low infrastructure complexity,
- fast deployment,
- public demo availability.

The app is not expected to scale horizontally or support production workloads during the course project.

---

# Why Fly.io

Fly.io is the best fit because:

- the repository is already prepared for Fly.io,
- Rails + Docker deployment is simple,
- SQLite volumes are supported,
- hosting cost is relatively low,
- the app is a classic Rails backend, not an edge/serverless app.

---

# Platform Notes

## Rejected platforms

| Platform | Reason |
|---|---|
| Cloudflare Workers/Pages | not suitable for Rails + Puma + SQLite |
| Vercel | Ruby support is limited |
| Netlify | no long-running Rails server support |

## Alternatives considered

| Platform | Notes |
|---|---|
| Railway | good alternative, but more usage-based pricing |
| Render | technically good, but more Postgres-oriented |

---

# Final Infrastructure

| Layer | Decision |
|---|---|
| Hosting | Fly.io |
| Runtime | Docker + Puma |
| Database | SQLite |
| Persistence | Fly volume |
| Scaling | single machine |
| Region | `fra` |
| Secrets | Fly secrets |
| CI | GitHub Actions |
| AI provider | OpenAI |

---

# SQLite Decision

SQLite is intentionally used for MVP/demo purposes to reduce cost and simplify deployment.

Accepted trade-offs:

- no horizontal scaling,
- single-instance deployment,
- minimal backup strategy,
- demo data may be lost,
- no HA/failover.

These limitations are acceptable for the course-project MVP.

---

# Security Notes

The following project rules remain important:

- raw logs are never persisted,
- raw logs are never sent to AI,
- sanitized data is encrypted at rest,
- secrets are managed through Fly secrets.

Required secrets:

```text
RAILS_MASTER_KEY
OPENAI_API_KEY
RAILS_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
RAILS_ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
RAILS_ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
```

---

# Deployment Strategy

Initial deployment flow:

```text
Local development
→ manual fly deploy
→ public demo URL
```

CI/CD auto-deployments can be added later.

---

# Required Fly.io Change

Before first deploy:

```toml
primary_region = "fra"
```

instead of deprecated:

```toml
primary_region = "waw"
```

---

# Main Commands

## Login

```bash
fly auth login
```

## Create volume

```bash
fly volumes create data --region fra --size 1 --app safelog-ai
```

## Set secrets

```bash
fly secrets set RAILS_MASTER_KEY="$(cat config/master.key)"
```

## Deploy

```bash
fly deploy --app safelog-ai
```

## Logs

```bash
fly logs --app safelog-ai
```

---

# Out of Scope

Not planned for MVP:

- Kubernetes
- autoscaling
- Redis
- background jobs
- multi-region deployment
- advanced observability
- staging environments
- production-grade infrastructure

---

# Summary

SafeLog AI infrastructure is intentionally optimized for:

- simplicity,
- fast MVP delivery,
- low hosting cost,
- public demo deployment.

It is intentionally not optimized for scale or enterprise production usage.
