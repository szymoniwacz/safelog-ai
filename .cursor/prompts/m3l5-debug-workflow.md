# M3L5 — Debug z AI: stack trace → hipoteza → fix → gate

Workflow debugowania kodu w SafeLog AI przez **Agent chat** + hooki QA (M3L3).
Łączy się z E2E smoke (`.cursor/prompts/m3l4-e2e-smoke.md`) gdy objaw jest w UI, nie w RSpec.

**Cel lekcji:** agent nie zgaduje — najpierw dowody, potem hipotezy, potem minimalny fix, potem ten sam gate zielony.

## Risk protected

Regresje i błędy logiczne są naprawiane z **uzasadnioną przyczyną** (linia w stack trace / spec), a nie „łataniem” expectów bez weryfikacji gate’em.

## Prerequisites

- Hooki QA: `.cursor/hooks.json` (`qa_failure_context.py`, `qa_failure_followup.py`).
- Komendy gate zgodne z `context/foundation/test-plan.md` §6.7.
- Uruchamiaj testy **z Agent chat** (Shell tool), żeby hook wstrzyknął `[qa-hook]` — nie z zewnętrznego terminala, jeśli testujesz sam pipeline hooków.

## Schemat pętli

```text
OBJAW (fail / 500 / UI)
  → ZBIERZ (SCOPE)
  → HIPOTEZY (max 3)
  → TEST falsyfikujący (jedna zmienna)
  → FIX minimalny
  → GATE (ten sam rspec / bin/ci)
  → PASS lub wróć do ZBIERZ
```

Hook M3L3 automatyzuje tylko krok **ZBIERZ** (output + ścieżki spec). Kroki **HIPOTEZA → FIX** wymuszają prompty poniżej.

## SCOPE — pakiet dowodów dla agenta

Wklej lub poproś agenta uzupełnić przed jakąkolwiek edycją kodu:

| Litera | Co | Przykład SafeLog |
|--------|-----|------------------|
| **S** — Stack trace | Pełny failure z RSpec (hook poda skrót) | `Failure/Error: expect(raw_value).to be_present` + `./spec/models/encryption_at_rest_spec.rb:26` |
| **C** — Context | Plik, linia, co test sprawdza | `expect_ciphertext_at_rest` → surowa kolumna SQLite ≠ plaintext |
| **O** — Oczekiwanie | Co powinno być prawdą | `raw_value` present, bez `plaintext_marker` w DB |
| **P** — Próby | Co już wiadomo / co wykluczone | np. „nie zmieniano kluczy encryption” |
| **E** — Env | Komenda, env | `mise exec -- bundle exec rspec spec/models/encryption_at_rest_spec.rb:26` |

## Prompty (Agent chat)

### A — Debug z dowodem (domyślny)

```text
RSpec pada. Użyj [qa-hook] jeśli jest w kontekście.

Zanim zmienisz kod:
1. Wypełnij SCOPE (krótko, punktami).
2. Wypisz 2–3 hipotezy.
3. Dla każdej: która linia stack trace ją wspiera lub obala.
4. Zaproponuj JEDEN test falsyfikujący (jedna zmienna).

Dopiero potem minimalny fix. Na końcu uruchom tę samą komendę rspec co wywołała błąd.
Jeśli nie masz dowodu na root cause — napisz UNKNOWN i co uruchomić dalej.
```

### B — Po fixie (regresja)

```text
Uruchom: mise exec -- bundle exec rspec spec/models/encryption_at_rest_spec.rb
Potem: mise exec -- bin/ci
Podsumuj: przyczyna → fix → wynik gate (liczby examples/failures).
```

### C — UI + kod (multimodal, opcjonalnie)

Wymaga `mise exec -- bin/dev` + Playwright MCP. Zobacz `m3l4-e2e-smoke.md`.

```text
Playwright MCP: wykonaj smoke z .cursor/prompts/m3l4-e2e-smoke.md.
Jeśli UI fail a rspec pass (lub odwrotnie): rozdziel hipotezy „widok” vs „backend”.
Do fixu backendu użyj promptu A. Nie wklejaj raw logów do formularzy.
```

## Eksperyment kalibracyjny (hook + SCOPE)

Celowy błąd do nauki pipeline’u — **cofnij przed commitem**.

1. W `spec/models/encryption_at_rest_spec.rb` linia z `debugging_case.id` w `expect_ciphertext_at_rest` → tymczasowo `debugging_case.id + 1`.
2. Agent chat:

```text
mise exec -- bundle exec rspec spec/models/encryption_at_rest_spec.rb:26
```

3. **Assert:** `[qa-hook]` + ścieżka spec; opcjonalnie followup po `stop` (self-healing, max 3 pętle).
4. Agent z promptem **A** powinien wskazać: brak wiersza w DB → `raw_value` nil (nie „encryption broken”).
5. Cofnij `id + 1` → `id` → ten sam rspec **0 failures**.

## Pass criteria

- [ ] Jedna sesja z intentional break (eksperyment kalibracyjny) — hipoteza trafiona przed fixem.
- [ ] Ten sam spec zielony po revert/fix.
- [ ] Agent nie edytował kodu w pierwszej turze bez SCOPE + hipotez (prompt A).

## Out of scope

- Debugowanie **produkcyjnych** logów w aplikacji (to domena produktu SafeLog — sanitized evidence, hipotezy w raporcie AI).
- Wklejanie raw logów / sekretów do czatu agenta.
- Nowe hooki — M3L5 używa istniejących z M3L3.
- Playwright w `bin/ci` (test-plan §7).

## Powiązania

| Artefakt | Rola |
|----------|------|
| `.cursor/hooks.json` | Auto-kontekst po fail rspec/ci |
| `context/foundation/test-plan.md` | Risk map + gate commands |
| `.cursor/prompts/m3l4-e2e-smoke.md` | Warstwa przeglądarki |
| `AGENTS.md` | Guardrails (brak raw w persist/AI) |

## Verified

_(uzupełnij datą po pierwszej sesji z promptem A + eksperymentem kalibracyjnym)_
