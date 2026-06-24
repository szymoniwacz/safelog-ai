# F5 Rails test log guard — operational checklist

Manual companion to the automated **Rails test log guard** example in
`spec/requests/debugging_cases_security_spec.rb`. TD-9 tracks the
`filter_parameter_logging` process gap; this artifact documents scope limits
and dev smoke steps the spec cannot replace.

## What the automated spec proves (test environment only)

After `POST /debugging_cases`, bytes **appended** to `log/test.log` since the
example started must not contain raw intake substrings (unique email, bearer
token, and shared request id from the security fixture).

- **Oracle:** `assert_no_raw_substring_in_appended_test_log` in
  `spec/support/security_persistence_helpers.rb`
- **Mechanism:** Rails request logging in **test** env writes a filtered
  `Parameters:` line when `config.filter_parameters` masks intake keys
- **Params covered today** (`config/initializers/filter_parameter_logging.rb`):
  `:pasted_content`, `:content`, `:raw`, `:log`, `:body`, and case metadata
  that may carry pasted secrets before redaction (`:customer_reference`,
  `:title`, `:description`, `:environment`), plus generic secret-like keys
  (`:passw`, `:email`, `:secret`, `:token`, …)

This closes builder readiness **F5** for CI: a regression that stops filtering
intake params in the test request log should fail the spec.

## What the automated spec does NOT prove

| Gap | Why |
|-----|-----|
| `log/development.log` | Not read or scanned at runtime |
| `log/production.log` | Not read or scanned at runtime |
| SQL bind / query lines in any log | Helper scans appended file bytes only; bind logging is out of scope |
| Stdout, stderr, Docker/Fly log sinks | No automated tail in CI |
| Custom `Rails.logger` / third-party gem logs | Would require separate review; no `Rails.logger` in `app/` today |

Persisted-data and AI-prompt oracles (`assert_no_raw_substring_in_persisted_data`,
analyze security specs) remain the canonical proof for risks #1 and #2; F5 adds
**request Parameters log** coverage in test env only.

## Manual dev smoke (after changing filter params or intake fields)

Run when you touch `filter_parameter_logging.rb`, add a new intake param that
can hold pasted secrets before redaction, or rename nested `debugging_case`
keys.

1. **Register the param** — add the new key (or nested path) to
   `config/initializers/filter_parameter_logging.rb`.
2. **Restart** — `bin/dev` / Puma must reload initializers.
3. **Submit with a unique marker** — create a case via UI or HTTP with a fresh
   secret in `pasted_content` and in any new metadata field, e.g.
   `dev-smoke-<random>@secret.example` and `sk-dev-smoke-<random>`.
4. **Inspect dev log** — `grep` (or tail) `log/development.log` for those
   exact substrings; neither the `Parameters:` line nor other request lines
   should contain them.
5. **Optional SQL check** — with verbose SQL logging enabled locally, confirm
   bind values for intake inserts do not echo raw paste (manual grep only).
6. **Re-run the automated guard:**

   ```bash
   mise exec -- bundle exec rspec spec/requests/debugging_cases_security_spec.rb -e "log guard"
   ```

## Related references

- Cookbook: `context/foundation/test-plan.md` §6.10
- Builder F5 note: `context/reviews/m1-m3-builder-readiness-review.md`
- Research gap (TD-9): `context/changes/case-submission-flow-analysis/research.md`
