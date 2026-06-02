# M3L4 — E2E smoke: sign-in → dashboard

Manual browser smoke for SafeLog AI via **Playwright MCP** against a running local app.
Validates the authenticated happy path across routing, Devise session, and server-rendered dashboard — not a substitute for request specs.

**CI:** Do **not** wire this into `bin/ci`. Per `context/foundation/test-plan.md` §7, browser e2e / Playwright flows stay out of the automated gate; request specs cover auth and case HTTP paths.

## Risk protected

Unauthenticated users are redirected to Devise sign-in; after login, `root` (`dashboard#show`) renders a usable workspace shell — not 404, not a blank error page.

## Prerequisites

- App running: `mise exec -- bin/dev` (or Puma on port 3000).
- Playwright MCP enabled (`.cursor/mcp.json`).
- Local dev database prepared (`mise exec -- bin/setup` or `db:prepare`).

## Test data

Aligned with `spec/factories/users.rb`:

| Field | Value |
|-------|-------|
| Email | `e2e-smoke@example.com` |
| Password | `password123` |

Seed the user once if missing:

```bash
mise exec -- bin/rails runner "
  User.find_or_create_by!(email: 'e2e-smoke@example.com') do |u|
    u.password = 'password123'
    u.password_confirmation = 'password123'
  end
"
```

Do not paste log content or other sensitive payloads into the browser during this smoke.

## Steps

### 1. Open root (guest)

- Navigate to `http://localhost:3000`.

**Assert**

- Final URL is `/users/sign_in` (302 redirect before login).
- Page title is `SafeLog AI`.
- Heading `Sign in to SafeLog AI` is visible.
- Form fields: textbox `Email`, textbox `Password`, button `Sign in`.

### 2. Sign in

- Fill `Email` with `e2e-smoke@example.com`.
- Fill `Password` with `password123`.
- Click button `Sign in`.

**Assert**

- Redirect to `http://localhost:3000/` (dashboard root).
- Flash/status includes `Signed in successfully.`
- No 404 or generic Rails error page.

### 3. Dashboard loaded

**Assert**

- Heading `SafeLog AI` (level 1) is visible.
- Text `Signed in as e2e-smoke@example.com.` is visible.
- Navigation (`Main`): links `Dashboard`, `Cases`, `New case`; user email shown; button `Sign out`.
- Actions: link `Debugging cases`, link `New debugging case`; button `Load demo case` (when demo data is available).
- Hint copy about redaction in memory is present (sanitized evidence only — no raw log intake in this flow).

### 4. Console (optional)

- Browser console has **zero** `error`-level messages for this session.

## Pass criteria

All assertions in steps 1–3 pass. Step 4 is informational.

## Out of scope

- Case creation, log paste, analyze, or AI report flows.
- Registration, password reset, or sign-out round-trip.
- Automated Playwright spec in repo or `bin/ci` (see test-plan §7).

## Verified

2026-06-02 — Playwright MCP against `localhost:3000`: guest redirect → Devise sign-in → dashboard shell green, 0 console errors.
