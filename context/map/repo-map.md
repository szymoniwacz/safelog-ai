# SafeLog AI — Repo map (onboarding)

**Synthesized from:** [artifact-1-territory](artifact-1-territory.md) · [artifact-2-structure](artifact-2-structure.md) · [artifact-3-contributors](artifact-3-contributors.md)  
**Updated:** 2026-06-09 · **Map window:** git/structure analysis over requested 12 months (actual repo age ~3 weeks)

---

## 1. TL;DR

SafeLog AI to **Rails 8 monolith** (SQLite, Devise, server-rendered ERB): użytkownik wkleja logi, backend **redaguje w pamięci**, zapisuje tylko sanityzowane dowody, potem generuje **hipotezyczny** raport AI — surowe logi nigdy nie trafiają do DB ani do modelu. To **młody solo MVP** (~3 tygodnie historii), nie legacy monolith — mapa opisuje kierunek pracy, nie wieloletnią specjalizację zespołu.

**Gdzie żyje praca (runtime):** `app/services/*` (pipeline), cienki HTTP w `app/controllers`, UI w `app/views/debugging_cases/`, oracles w `spec/requests` i `spec/services`. **Gdzie git jest głośny, a produkt nie:** `context/changes/` i `context/archive/` — dokumentacja slice'ów 10x, nie kod deployowalny.

**Gdzie boli:** orchestrator `Analysis::AnalyzeCase`, korytarz HTTP (`routes → controller → views → request specs`), security oracles, hub E2E `e2e/helpers.ts`. **Brak cykli** w serwisach Ruby; granica **`redaction ⊥ ai`** utrzymana.

**Kontrybutorzy:** jeden maintainer (Szymon Iwacz) — mapa „kogo zapytać” to routing tematyczny + fallback do `context/foundation/`.

```mermaid
flowchart TB
  subgraph http [HTTP — artifact-1 spine]
    Routes[config/routes.rb]
    Ctrl[DebuggingCasesController]
    Views[app/views/debugging_cases]
    ReqSpec[spec/requests]
  end
  subgraph domain [Domain pipeline — Ruby DAG, artifact-2]
    Intake --> Redaction
    Analysis --> Correlation
    Analysis --> Ai
  end
  subgraph outer [Peryferia / docs — high git, non-runtime]
    CtxChanges[context/changes]
    CtxArch[context/archive]
  end
  Routes --> Ctrl --> Views
  Ctrl --> Intake
  Ctrl --> Analysis
  Views -.-> ReqSpec
  Ctrl -.-> ReqSpec
  Redaction -.->|must not reach| Ai
```

---

## 2. Teren

### Duża odpowiedzialność vs peryferia

| Strefa | Głębokość | Git activity | Runtime? |
|--------|-----------|--------------|----------|
| **Pipeline serwisów** (`intake`, `redaction`, `correlation`, `analysis`, `ai`) | Głęboka — logika produktu, guardrails PRD | Średnia (33 touches w `app/services/`) | **Tak** |
| **HTTP slice** (controller, views, routes) | Średnia — orchestracja + UI | Wysoka (views #3, controller #8) | **Tak** |
| **Security oracles** (`spec/requests/*_security*`) | Głęboka — kontrakt bezpieczeństwa | Najwyższa runtime (#1: 32 touches) | **Tak (testy)** |
| **`context/changes/`** | Płytko w sensie deploy — plany slice'ów | **Najwyższa w repo (#1: 146)** | **Nie** — wygląda jak moduł, nim nie jest |
| **Deploy / cert / E2E** | Płytsza warstwa operacyjna | Wzrost w czerwcu 2026 | Częściowo (Fly, Playwright) |
| **Devise / dashboard** | Płytkie — auth scaffold | Niskie vs debugging_cases | Tak, peryferia produktu |

**Iluzja katalogowa:** pierwszy w rankingu git folder to `context/changes/` — to **workflow dokumentacyjny**, nie bounded context runtime. Ukończone slice'y → `context/archive/`. Aktywny `context/changes/` to dziś praktycznie tylko `README.md`.

### Aktywność w czasie

- **Maj 2026:** feature verticals (intake, redaction, analyze, AI, encryption) + archiwizacja slice'ów.
- **Czerwiec 2026:** certification, deploy, Playwright, foundation/reviews.

Trend: planowe slice'y, bez „hotspotu naprawczego” w jednym pliku (artifact-1).

---

## 3. Realne powiązania

Couplingi z **źródłem dowodu** — nie mylić braku grafu z brakiem powiązań.

| Powiązanie | Typ | Źródło | Koszt zmiany |
|------------|-----|--------|--------------|
| `routes` ↔ `controller` ↔ `spec/requests` | Ręczna edycja, vertical slice | **Git co-change** (6 commitów runtime) | Wysoki — dotykasz HTTP + oracle |
| `controller` ↔ `views/debugging_cases` | Ręczna edycja | **Git co-change** (7 commitów) | Średni — UI + request/system specs |
| `app/services` ↔ `spec/services` | Ręczna edycja (TDD slice) | **Git co-change** (13 commitów) | Średni — domain + unit tests |
| `intake` → `redaction` | Jednokierunkowy DAG | **Ruby constant scan** (artifact-2); brak depcruise dla Ruby | Wysoki — cały sanitized content |
| `analysis` → `correlation` + `ai` | Orchestracja | **Ruby constant scan** | Bardzo wysoki — `AnalyzeCase` |
| `redaction` ⊥ `ai` | Granica bezpieczeństwa (brak importów) | **Ruby constant scan** | Naruszenie = krytyczne |
| `context/changes` ↔ `spec/requests` | Workflow 10x (plan + spec w 1 commicie) | **Git co-change** (19) | Niski dla runtime — docs + kod |
| `e2e/*.spec.ts` → `helpers.ts` → Playwright | Hub testowy | **dependency-cruiser** (fan-in 4, 0 violations) | Średni — zmiana helpera = cały E2E |
| Ruby + E2E service graph | **Brak cykli** (DAG / star) | **Ruby constant scan** + **dependency-cruiser** (artifact-2) | Niski — brak pętli do rozpisywania przy refaktorze |
| `spec/*` + CI ↔ `Ai::FakeClient` | **Mock / stub** (nie ręczna integracja OpenAI) | Konwencja test-plan + `ClientResolver` w `test` | Niski w CI — real API tylko gdy `OPENAI_API_KEY` poza testami |
| `db/schema.rb` | **Regeneracja** (`db:migrate`) | Git (wykluczone jako szum w artifact-1) | Tańszy niż ręczna edycja — nie traktować jak hotspot |
| Ruby service graph (pełny autoload) | — | **unknown** — static scan ≠ runtime autoload; ~25 plików serwisów | Uznaj couplingi Ruby za potwierdzone scanem, nie za kompletne |

Najcięższy orchestrator: `Analysis::AnalyzeCase`.

---

## 4. Strefy ryzyka

| # | Strefa | Dlaczego |
|---|--------|----------|
| 1 | **Security oracles** (`spec/requests/*_security_spec.rb`) | Jedyny trwały kontrakt „raw logs never persist / never reach AI” — regresja łamie narrację produktu |
| 2 | **`Analysis::AnalyzeCase`** | Fan-out: Correlation + Ai + AR + retry; najwyższy koszt testów i refaktoru (artifact-2) |
| 3 | **HTTP slice** (`debugging_cases_controller`, views, routes) | Najciasniejsze co-change w runtime; każda akcja HTTP ciągnie request specs |
| 4 | **`Intake::ProcessCaseSubmission` + `Redaction::Engine`** | Jedyny moment kontaktu z surowym paste; błąd = wyciek przed redakcją |
| 5 | **`e2e/helpers.ts`** | Fan-in 4 — jedna zmiana locatorów kładzie cały Playwright (depcruise) |
| 6 | **Public Fly vs local demo** | `load_demo` tylko dev/test; reviewerzy Fly używają manual intake — łatwo pomylić z bugiem deployu |

---

## 5. Kogo zapytać

Solo MVP — **jeden kontakt**, bez fikcyjnego RACI. Fallback gdy maintainer niedostępny.

| Strefa ryzyka | Kontakt | Fallback |
|---------------|---------|----------|
| Security oracles | Szymon Iwacz | `context/foundation/test-plan.md`, `spec/requests/debugging_cases_security_spec.rb` |
| Analyze + AI | Szymon Iwacz | `app/services/analysis/analyze_case.rb`, `context/archive/…/analyze-hypothesis-report/` |
| HTTP slice | Szymon Iwacz | `config/routes.rb`, `spec/requests/debugging_cases_*` |
| Intake / redaction | Szymon Iwacz | `context/foundation/prd.md`, `spec/services/redaction/` |
| Deploy / E2E / cert | Szymon Iwacz | `context/deployment/deploy-plan.md`, `context/certification/certification-readiness.md` |
| Dokumentacja slice / historia decyzji | Szymon Iwacz | `context/archive/` (nie aktywny `context/changes/`) |

---

## 6. Pierwszy dzień — co czytać (kolejność ~15 min)

1. **`context/foundation/prd.md`** + **`context/foundation/shape-notes.md`** — guardrails produktu: redaction before AI, brak raw persistence.
2. **`app/controllers/debugging_cases_controller.rb`** — wejście HTTP; widać które serwisy woła.
3. **`app/services/intake/process_case_submission.rb`** — intake + redaction w transakcji.
4. **`app/services/redaction/engine.rb`** — placeholder engine (pure domain).
5. **`app/services/analysis/analyze_case.rb`** — orchestrator analyze (największe ryzyko).
6. **`app/services/ai/client_resolver.rb`** + **`fake_client.rb`** — granica AI / testy bez real API.
7. **`spec/requests/debugging_cases_security_spec.rb`** — oracle bezpieczeństwa (must-not-break).
8. **`AGENTS.md`** — twarde reguły dla agentów i contributorów.

Opcjonalnie po pierwszym flow: `context/map/artifact-1-territory.md` (gdzie git żyje) i `artifact-2-structure.md` (DAG + granice).

---

## 7. Ograniczenia

**Okno i metoda**

- Analiza git: requested 12 months, **faktycznie ~3 tygodnie** (2026-05-18 → 2026-06-09, ~116 commitów). Trendy są kierunkowe, nie statystycznie robust.
- **Territory / co-change:** `git log` + filtr szumu (artifact-1).
- **Struktura Ruby:** static `Module::Class` scan — **nie** pełny graf autoload (oznaczone jako **unknown** tam, gdzie depcruise nie obejmuje Ruby).
- **Struktura E2E:** dependency-cruiser tylko na ~7 plikach TS (`e2e/`, Playwright).
- **Kontrybutorzy:** 1 autor; brak botów w historii; assist AI niewidoczny w metadanych git.

**Czego mapa NIE mówi**

- Nie rankuje `context/changes/` jako modułu deployowalnego mimo wysokiego git churn.
- Nie zastępuje `context/foundation/test-plan.md` ani procedur CI — wskazuje gdzie te procedury „przyklejone” do kodu.
- Nie obiecuje mapy zespołu — bus factor = 1.
- Nie obejmuje roadmapy post-MVP (Postgres, observability) — parked w foundation/roadmap.

**Artefakty źródłowe (szczegóły):** [artifact-1](artifact-1-territory.md) · [artifact-2](artifact-2-structure.md) · [artifact-3](artifact-3-contributors.md) · [E2E graph](diagrams/e2e-helper-hub.svg)
