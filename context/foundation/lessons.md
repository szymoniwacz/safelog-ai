# Lessons Learned

> Append-only register of recurring rules and patterns. Re-read at start by /10x-frame, /10x-research, /10x-plan, /10x-plan-review, /10x-implement, /10x-impl-review.

## Prefer surgical updates to agent guidance

- **Context**: Agent onboarding, project rules, and changes to AGENTS.md / CLAUDE.md / context files during Module 1 setup.
- **Problem**: The agent tends to over-edit or rewrite generated project guidance instead of applying the smallest useful correction. This can make AGENTS.md too long, duplicate PRD content, and increase context noise before real implementation starts.
- **Rule**: Prefer minimal, surgical updates to generated agent/project guidance. Do not rewrite the whole file unless explicitly asked; preserve useful generated content and only strengthen rules that are missing, ambiguous, or risky.
- **Applies to**: plan, plan-review, implement, impl-review

## Fly.io: Thruster `HTTP_PORT` vs `PORT`

- **Context**: First production deploy to Fly.io with Rails 8 Thruster (`./bin/thrust ./bin/rails server`), non-root container user, `internal_port = 8080`.
- **Problem**: Thruster binds `HTTP_PORT` (default 80), not `PORT`. Non-root cannot bind :80 → `permission denied`. Fly health checks then hit `/up` with machine IP as Host → Rails `HostAuthorization` 403 unless `/up` is excluded.
- **Rule**: On Fly with Thruster + non-root: set `HTTP_PORT=8080` in `fly.toml` and Dockerfile; exclude `/up` from `config.host_authorization`. Use `fly apps create` + `fly deploy`, not `fly launch` (overwrites project config). Create volume before first mount deploy.
- **Applies to**: implement, deploy-plan, infrastructure docs
