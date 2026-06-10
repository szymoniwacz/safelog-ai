---
title: Anti-Corruption Layer — AI Adapter Boundary
created: 2026-06-10
type: refactor-plan
focus: app/services/ai/
source_distillation: context/domain/01-domain-distillation.md
---

# Anti-Corruption Layer — granica adaptera AI

Plan refaktoru DDD (bez implementacji kodu produkcyjnego). Skupienie: **provider-agnostic AI adapter** zadeklarowany w PRD/shape-notes vs rzeczywiste przecieki `Ai::` do warstwy Analysis i HTTP.

---

## KROK 0 — Kontekst

### Deklaracje wymienialności (intencja)

| Dokument | Cytat | Plik:linia |
|----------|-------|------------|
| Shape notes | „Provider-agnostic AI adapter; OpenAI as first real provider" | `context/foundation/shape-notes.md:187` |
| Tech stack | „Provider-agnostic adapter \| `Ai::FakeClient` in test/CI; OpenAI optional via `OPENAI_API_KEY`" | `context/foundation/tech-stack.md:30` |
| README | „`Ai::` — Client contract, fake/OpenAI adapters, response validation" | `README.md:130` |
| Repo map (artifact-2) | „AI adapter swappable (FakeClient/OpenAI) without touching redaction" | `context/map/artifact-2-structure.md:74` |
| F-03 plan | „Provider-agnostic AI client under `app/services/ai/`" … „`Ai::Client` contract `#complete(request)`" | `context/archive/2026-05-27-ai-adapter-foundation/plan.md:5,28` |
| PRD guardrail | AI reports hypotheses only; analyze from sanitized evidence (`FR-007`, `FR-008`) | `context/foundation/prd.md:60,115–118` |
| AGENTS | Tests must use fake AI client; CI never calls real providers | `AGENTS.md:14` |

### Stack i zależności zewnętrzne

| Warstwa | Technologia | Manifest |
|---------|-------------|----------|
| Framework | Rails 8.1, server-rendered ERB | `Gemfile` |
| AI SDK | **`ruby-openai` 8.3.0** → `OpenAI::Client` | `Gemfile:24`, `Gemfile.lock:355` |
| Test HTTP stub | WebMock | `context/foundation/test-plan.md:86` |
| Warstwy kodu | HTTP → `Analysis::` → `Ai::` → HTTP OpenAI | `README.md:122–131` |

### Obecna struktura `app/services/ai/`

| Plik | Rola |
|------|------|
| `client.rb:4–7` | Moduł portu `#complete` |
| `request.rb:9–47` | Envelope request (messages role/content — kształt Chat Completions) |
| `completion_result.rb:4–18` | Wynik adaptera (structured hash + markdown) |
| `open_ai_client.rb:14–58` | Adapter OpenAI — jedyne miejsce z `OpenAI::Client` |
| `fake_client.rb:4–19` | Stub deterministyczny |
| `client_resolver.rb:4–14` | Fabryka env-gated |
| `response_validator.rb:6–107` | Walidacja hypothesis schema |
| `report_schema.rb:13–53` | Kontrakt JSON raportu |

Granica bezpieczeństwa redaction ⊥ AI jest **zachowana** — brak importów `Redaction::` / `Intake::` w `app/services/ai/*.rb` (`artifact-2-structure.md:74`).

---

## KROK 1 — Przeciekające zależności

### Z1 — `ruby-openai` / `OpenAI::Client` (SDK OpenAI)

| Plik | Linia | Jak „zna" |
|------|-------|-----------|
| `app/services/ai/open_ai_client.rb` | 15 | `OpenAI::Client.new(access_token: api_key)` |
| `app/services/ai/open_ai_client.rb` | 17, 19 | `@client.chat(parameters: …)` |
| `app/services/ai/open_ai_client.rb` | 35 | `response_format: { type: "json_object" }` — specyfika OpenAI |
| `spec/services/ai/open_ai_client_spec.rb` | 8 | `instance_double(OpenAI::Client)` |

**Ocena:** SDK **dobrze zamknięte** w jednym adapterze runtime. Brak przecieku do UI/kontrolera.

---

### Z2 — `Ai::Request` (format wire Chat Completions)

Envelope `{ role:, content: }[]` — kształt API OpenAI, adoptowany jako kontrakt międzywarstwowy.

| Plik | Linia | Jak „zna" |
|------|-------|-----------|
| `app/services/analysis/prompt_builder.rb` | 4, 17–23 | Buduje i zwraca `Ai::Request.new(messages: …)` |
| `app/services/ai/open_ai_client.rb` | 18, 31–36 | `#complete(request)` mapuje `request.messages` |
| `app/services/ai/fake_client.rb` | 9–10 | `@last_request = request` |
| `app/services/ai/request.rb` | 9–47 | Definicja klasy |
| `spec/services/ai/request_spec.rb` | 5–36 | Testy kształtu |
| `spec/services/ai/open_ai_client_spec.rb` | 10–12 | Fixture request |
| `spec/services/ai/fake_client_spec.rb` | 9–11 | Fixture request |
| `spec/services/ai/sanitized_prompt_guard_spec.rb` | 22, 31, 40 | Bezpośrednie konstrukcje |

**Ocena:** **Analysis zna format providera** — klasyczny brak ACL.

---

### Z3 — `Ai::Client` + `Ai::ClientResolver` (port adaptera w orchestracji i HTTP)

| Plik | Linia | Jak „zna" |
|------|-------|-----------|
| `app/services/analysis/analyze_case.rb` | 13, 17–19, 60 | Default `client: Ai::ClientResolver.current`; `@client.complete(request)` |
| `app/controllers/debugging_cases_controller.rb` | 25 | `@fake_ai_client_active = Ai::ClientResolver.fake_client_active?` |
| `app/services/ai/client_resolver.rb` | 4–14 | Implementacja |
| `app/services/ai/client.rb` | 4–7 | Moduł kontraktu |
| `app/services/ai/fake_client.rb` | 5 | `include Client` |
| `app/services/ai/open_ai_client.rb` | 5 | `include Client` |
| `spec/services/analysis/analyze_case_spec.rb` | 28, 53, 69, 84 | `Ai::FakeClient.new` |
| `spec/support/ai_test_clients.rb` | 5, 11, 27 | `include Ai::Client`; fallback FakeClient |
| `spec/requests/debugging_cases_security_spec.rb` | 84–87, 118–121, 182–185, 243–246 | Stub resolver → FakeClient |
| `spec/requests/debugging_cases_analyze_security_spec.rb` | 7, 13 | j.w. |
| `spec/requests/debugging_cases_report_export_security_spec.rb` | 8, 14 | j.w. |
| `spec/requests/debugging_cases_analyze_spec.rb` | 72 | Stub InvalidClient |
| `spec/requests/debugging_cases_authorization_spec.rb` | 82–83 | j.w. |
| `spec/requests/debugging_cases_spec.rb` | 166 | Stub `fake_client_active?` |
| `spec/services/ai/client_resolver_spec.rb` | 5, 8 | Unit resolver |
| `spec/services/ai/sanitized_prompt_guard_spec.rb` | 8, 39 | Resolver + FakeClient |

**Ocena:** Port adaptera **wycieka do HTTP (UI flag)** i **do wszystkich request speców** — wymiana providera wymaga dotknięcia kontrolera i ~8 plików spec.

---

### Z4 — `Ai::CompletionResult` (typ wyniku adaptera w orchestracji)

| Plik | Linia | Jak „zna" |
|------|-------|-----------|
| `app/services/analysis/analyze_case.rb` | 36–37 | `completion.structured`, `completion.markdown` |
| `app/services/ai/completion_result.rb` | 4–18 | Definicja |
| `app/services/ai/open_ai_client.rb` | 23–26 | Tworzenie |
| `app/services/ai/fake_client.rb` | 15–18 | Tworzenie |
| `spec/support/ai_test_clients.rb` | 19, 39 | Invalid fixture |

---

### Z5 — `Ai::InvalidResponseError` + `Ai::ResponseValidator` (semantyka adaptera w orchestracji)

| Plik | Linia | Jak „zna" |
|------|-------|-----------|
| `app/services/analysis/analyze_case.rb` | 41, 61, 63 | `rescue Ai::InvalidResponseError`; ponowne wołanie `ResponseValidator` |
| `app/services/ai/open_ai_client.rb` | 21 | Walidacja w adapterze |
| `app/services/ai/fake_client.rb` | 13 | Walidacja w fake |
| `app/services/ai/response_validator.rb` | 4, 6–107 | Definicja |
| `app/services/ai/report_schema.rb` | 14–15 | Klucze wymagane |
| `spec/services/ai/response_validator_spec.rb` | 5–76 | Unit |
| `spec/services/ai/fake_client_spec.rb` | 23 | Walidacja outputu fake |

**Duplikacja:** walidacja w `OpenAiClient`/`FakeClient` **i** ponownie w `AnalyzeCase#complete_with_retry` (`analyze_case.rb:61`).

---

### Z6 — `Ai::ReportSchema` (kontrakt providera w testach i fake)

| Plik | Linia | Jak „zna" |
|------|-------|-----------|
| `app/services/ai/report_schema.rb` | 13–53 | Definicja |
| `app/services/ai/response_validator.rb` | 32, 61 | REQUIRED_KEYS |
| `app/services/ai/fake_client.rb` | 12, 17 | Canonical fixture |
| `spec/services/ai/response_validator_spec.rb` | 8 | CANONICAL_STRUCTURED |
| `spec/services/ai/open_ai_client_spec.rb` | 14 | canonical_structured |

**Ocena:** Wewnątrz `Ai::` — OK; przeciek gdy testy budują invalid payload znając klucze schema zamiast portu domenowego.

---

## KROK 2 — Klasyfikacja i wybór #1

| ID | (a) Warstwy/pliki | (b) Koszt wymiany providera | (c) Deklarowana wymienialność | Werdykt |
|----|-------------------|----------------------------|-------------------------------|---------|
| Z1 OpenAI SDK | 1 adapter + 1 spec | Niski — celowo tu | Tak — zgodne | **OK** |
| **Z2+Z3+Z4+Z5 (pakiet)** | **Analysis (2) + HTTP (1) + Ai (8) + spec (~12)** | **Wysoki** — PromptBuilder, AnalyzeCase, controller, wszystkie request specs | **Rozjazd** — „swappable without touching redaction" implikuje też Analysis | **#1 najgorszy** |
| Z6 ReportSchema | Ai + specs | Średni | Częściowy | Wchodzi w pakiet Z2–Z5 |

### Wybór #1: **Przeciek kontraktu adaptera `Ai::` do kontekstu Analysis i HTTP**

Łączę Z2–Z5 jako jeden problem ACL: warstwa **Analysis** i **HTTP** operuje na typach **`Ai::Request`**, **`Ai::Client`**, **`Ai::CompletionResult`**, **`Ai::InvalidResponseError`**, **`Ai::ClientResolver`** zamiast na portcie domenowym „generuj raport hipotez z sanityzowanych dowodów".

**Uzasadnienie:**
- Dokumenty explicite deklarują adapter **provider-agnostic** (`shape-notes.md:187`, `tech-stack.md:30`), a F-03 plan zakłada wąski `Ai::Client` — lecz **S-03 (AnalyzeCase) i PromptBuilder zostały napisane „przez" ten kontrakt**, nie „obok" niego z ACL.
- Wymiana OpenAI → inny provider (Anthropic Messages API, lokalny LLM) wymaga dziś edycji `PromptBuilder` (format messages), `AnalyzeCase` (client injection, error handling), kontrolera (demo flag) i ~12 plików spec — **wbrew intencji artifact-2**.
- SDK `OpenAI::` jest izolowane (Z1); **prawdziwy koszt swapu siedzi w przecieku typów `Ai::`**, nie w gemie.
- Kontroler woła `ClientResolver.fake_client_active?` (`debugging_cases_controller.rb:25`) — **warstwa UI zna szczegóły implementacji AI**, nie stan produktu.

---

## KROK 3 — Diagnoza

### Rozjazd intencja vs kod

**Intencja** (`artifact-2-structure.md:74`): „AI adapter swappable (FakeClient/OpenAI) **without touching redaction**".

**Kod:** redaction nietknięte ✓, ale Analysis **musi** dotykać `Ai::`:

```17:23:app/services/analysis/prompt_builder.rb
      Ai::Request.new(
        messages: [
          { role: "system", content: system_message },
          { role: "user", content: user_message }
        ],
        case_ref: @debugging_case.id.to_s
      )
```

```13:14:app/services/analysis/analyze_case.rb
    def self.call(debugging_case:, client: Ai::ClientResolver.current)
```

```25:25:app/controllers/debugging_cases_controller.rb
    @fake_ai_client_active = Ai::ClientResolver.fake_client_active?
```

### Duplikacja walidacji (triple gate)

1. `open_ai_client.rb:21` — `ResponseValidator.call(structured)`
2. `fake_client.rb:13` — to samo
3. `analyze_case.rb:61` — **ponowna** walidacja po `@client.complete`

Orchestrator zna semantykę błędu adaptera:

```41:43:app/services/analysis/analyze_case.rb
    rescue Ai::InvalidResponseError
      ai_report&.update!(status: :failed, structured_json: nil, markdown_body: nil)
      failure(ai_report)
```

### UI jako strażnik wiedzy o providerze

`show.html.erb:17–18` renderuje notice na podstawie `@fake_ai_client_active` — flaga pochodzi z resolvera OpenAI-env (`client_resolver.rb:12–13`), nie ze stanu domeny „demo analysis mode".

### Co działa dobrze (nie psuć)

| Element | Dowód |
|---------|-------|
| SDK tylko w adapterze | `OpenAI::Client` — `open_ai_client.rb:15`; spec double — `open_ai_client_spec.rb:8` |
| Brak prompt persistence | Brak tabeli; `FakeClient#last_request` in-memory (`fake_client.rb:7–10`) |
| Sanitized-only upstream | Komentarz + testy — `prompt_builder.rb:4–5`; `sanitized_prompt_guard_spec.rb` |
| Redaction ⊥ AI | Brak cross-importów (`artifact-2-structure.md:118`) |

### Otwarte pytanie kontraktu OpenAI (rozstrzygnięcie w ACL)

**Pytanie:** Czy odpowiedź providera musi być `{ "structured": {...}, "markdown": "..." }` w jednym JSON?

**Decyzja (na podstawie `open_ai_client.rb:45–55` i F-03 plan):** Tak **dla adaptera OpenAI** — wymuszane przez `response_format: json_object` i parser w adapterze. To **wiedza infrastrukturalna**, nie domenowa. ACL mapuje ten envelope na `Analysis::HypothesisReport` wewnątrz `Ai::`, nigdy w `AnalyzeCase`.

**Alternatywny provider** może zwracać markdown + JSON osobno — translator w nowym adapterze, bez zmiany Analysis.

---

## KROK 4 — Projekt ACL

### Podział kontekstów

```
┌─────────────────────────────────────────────┐
│ Analysis (domain)                           │
│  EvidenceBundle, HypothesisReport (VO)      │
│  HypothesisGenerator (PORT)                 │
│  AnalyzeCase (orchestrator — zna tylko PORT)│
└──────────────────┬──────────────────────────┘
                   │ port
┌──────────────────▼──────────────────────────┐
│ Ai (ACL + infrastructure)                   │
│  HypothesisGeneratorAdapter (facade)        │
│  PromptTranslator → ChatRequest (internal)  │
│  OpenAiChatProvider (OpenAI::Client)        │
│  FakeHypothesisProvider                     │
│  ResponseValidator, ReportSchema (internal)   │
└─────────────────────────────────────────────┘
```

### Value objects domenowe (Analysis — jedyne miejsce wiedzy o „co" wysyłamy/wiadomo)

```ruby
module Analysis
  # Sanityzowany pakiet dowodów — zero wiedzy o Chat Completions
  class EvidenceBundle
    attr_reader :case_id, :title, :description, :environment,
                :customer_reference, :correlation_payload, :log_sources

    def self.from_debugging_case(debugging_case:, correlation_payload:)
      # mapuje AR → immutable structs (source_type, name, sanitized_content, position)
    end
  end

  # Raport hipotez — kontrakt PRD FR-008, nie JSON providera
  class HypothesisReport
    attr_reader :summary, :hypotheses, :uncertainty_notes,
                :correlation_highlights, :markdown_body

    def to_persistence_json
      { summary:, hypotheses:, uncertainty_notes:,
        correlation_highlights: }.compact.to_json
    end
  end

  class ReportGenerationError < StandardError; end  # port failure — nie Ai::InvalidResponseError
end
```

### Wąski port (interfejs domenowy)

```ruby
module Analysis
  module HypothesisGenerator
    # @param evidence [EvidenceBundle]
    # @return [HypothesisReport]
    # @raise [ReportGenerationError] — invalid/unusable provider output after retries
    def generate(evidence:)
      raise NotImplementedError
    end
  end
end
```

Reszta kodu (`AnalyzeCase`, controller, views) zna **tylko** `HypothesisGenerator` i `HypothesisReport`.

### ACL — adapter implementujący port

```ruby
module Ai
  class HypothesisGeneratorAdapter
    include Analysis::HypothesisGenerator

    def initialize(provider: ProviderResolver.current, validator: ResponseValidator)
      @provider = provider
      @validator = validator
    end

    def generate(evidence:)
      chat_request = PromptTranslator.to_chat_request(evidence)  # internal Ai type
      raw = @provider.complete(chat_request)
      report = ResponseTranslator.to_hypothesis_report(raw, validator: @validator)
      report
    rescue InvalidResponseError => e
      raise Analysis::ReportGenerationError, e.message
    end
  end

  # INTERNAL — nie wychodzi z app/services/ai/
  class PromptTranslator
    def self.to_chat_request(evidence)
      ChatRequest.new(
        messages: [
          { role: "system", content: system_instructions },
          { role: "user", content: format_evidence(evidence) }
        ],
        case_ref: evidence.case_id.to_s
      )
    end
  end

  class OpenAiChatProvider
    def complete(chat_request)
      response = @client.chat(parameters: openai_parameters(chat_request))
      extract_payload(response)  # { structured:, markdown: } — OpenAI envelope
    end
  end

  class FakeHypothesisProvider
    # Deterministyczny raport; opcjonalnie @last_evidence dla testów
  end
end
```

**Rename w planie:** `Ai::Request` → `Ai::ChatRequest` (internal); `Ai::Client#complete` → `Ai::ChatProvider#complete` — sygnalizuje, że to wire OpenAI, nie kontrakt domeny.

### Orchestrator po ACL

```ruby
module Analysis
  class AnalyzeCase
    def self.call(debugging_case:, generator: GeneratorResolver.current)
      # ...
      evidence = EvidenceBundle.from_debugging_case(
        debugging_case: debugging_case,
        correlation_payload: correlation_payload
      )
      report = complete_with_retry { generator.generate(evidence: evidence) }
      ai_report.update!(
        status: :generated,
        structured_json: report.to_persistence_json,
        markdown_body: report.markdown_body
      )
    rescue ReportGenerationError
      # failed status — bez referencji do Ai::
    end
  end
end
```

`PromptBuilder` → **`EvidenceBundle.from_debugging_case`** (usunięcie bezpośredniego `Ai::Request.new`).

### Demo flag — z kontrolera do konfiguracji aplikacji

```ruby
# app/services/analysis/generator_resolver.rb
module Analysis
  class GeneratorResolver
    def self.current
      Ai::HypothesisGeneratorAdapter.new(provider: Ai::ProviderResolver.current)
    end

    def self.demo_mode_active?
      !Rails.env.test? && ENV["OPENAI_API_KEY"].blank?
    end
  end
end
```

Controller (`debugging_cases_controller.rb:25`) → `@demo_analysis_mode = Analysis::GeneratorResolver.demo_mode_active?` — **zero importu `Ai::` w kontrolerze docelowo**, lub cienki helper w `Analysis::` namespace.

---

## KROK 5 — Dowód izolacji + before/after

### Kryterium sukcesu (grep)

Po refaktorze:

| Wzorzec grep | Dozwolone lokalizacje | Zabronione po refaktorze |
|--------------|----------------------|--------------------------|
| `OpenAI::` | `app/services/ai/open_ai_chat_provider.rb` (rename) + `spec/services/ai/*` | Analysis, controllers, views |
| `Ai::Request` / `Ai::ChatRequest` | `app/services/ai/**` + `spec/services/ai/**` | `app/services/analysis/**`, `app/controllers/**` |
| `Ai::ClientResolver` | **Usunięty** → `Ai::ProviderResolver` (internal) + `Analysis::GeneratorResolver` | controllers, request specs |
| `Ai::FakeClient` | `app/services/ai/**` + ewent. `spec/support` przez adapter | `spec/requests/**` bezpośrednio |
| `Ai::InvalidResponseError` | `app/services/ai/**` | `app/services/analysis/**` |
| `Analysis::HypothesisGenerator` | Analysis + test doubles | — |

### Before / after — zduplikowane miejsca

| Miejsce | Before | After |
|---------|--------|-------|
| `prompt_builder.rb:17–23` | Buduje `Ai::Request` | **`EvidenceBundle.from_debugging_case`** — logika przeniesiona z PromptBuilder |
| `analyze_case.rb:13,27–30,60–63` | `client.complete(Ai::Request)` + `Ai::ResponseValidator` | `generator.generate(evidence:)` → `HypothesisReport` |
| `analyze_case.rb:41` | `rescue Ai::InvalidResponseError` | `rescue Analysis::ReportGenerationError` |
| `debugging_cases_controller.rb:25` | `Ai::ClientResolver.fake_client_active?` | `Analysis::GeneratorResolver.demo_mode_active?` |
| `open_ai_client.rb:21` + `analyze_case.rb:61` | Podwójna walidacja | Walidacja **tylko** w ACL (`HypothesisGeneratorAdapter`); retry w AnalyzeCase na `ReportGenerationError` |
| Request specs (8 plików) | `allow(Ai::ClientResolver)... FakeClient` | Stub `Analysis::GeneratorResolver.current` → `Analysis::TestGenerators::CapturingGenerator` |
| `ai_test_clients.rb` | `include Ai::Client`; buduje `CompletionResult` | `Analysis::TestGenerators::InvalidGenerator` implementuje port |
| `fake_client.rb` | Zna `ReportSchema`, `Request` | Wchodzi w `FakeHypothesisProvider` — internal |
| UI `show.html.erb:17` | `@fake_ai_client_active` | `@demo_analysis_mode` — boolean domenowy |

### UI dostaje dane domenowe

| Dane | Before | After |
|------|--------|-------|
| Notice demo | Flaga z resolvera OpenAI env | `demo_mode_active?` — semantyka produktu |
| Raport na show | `ParseStructuredReport` parsuje JSON z DB | Bez zmian — JSON pochodzi z `HypothesisReport#to_persistence_json`, nie z envelope OpenAI |
| Analyze outcome | `AiReport` AR enum | Bez zmian — orchestrator mapuje `HypothesisReport` → AR |

---

## KROK 6 — Plan faz

Zgodnie z konwencją projektu: małe fazy, RSpec test-first, `bin/ci` green po każdej fazie.

| Faza | Zakres | Test-first | Pliki dotykane |
|------|--------|------------|----------------|
| **F1** | Wprowadź `Analysis::EvidenceBundle`, `HypothesisReport`, `ReportGenerationError`; `EvidenceBundle.from_debugging_case` (logika z `PromptBuilder`) | `spec/services/analysis/evidence_bundle_spec.rb` | `analysis/evidence_bundle.rb`, `prompt_builder.rb` (deprecate) |
| **F2** | Port `HypothesisGenerator`; `Ai::HypothesisGeneratorAdapter` delegujący do obecnego `FakeClient`/`OpenAiClient` przez translator | `spec/services/ai/hypothesis_generator_adapter_spec.rb` | nowe pliki w `ai/`, rename internal |
| **F3** | `AnalyzeCase` na porcie; usuń `Ai::` z orchestratora; retry na `ReportGenerationError` | `analyze_case_spec.rb` — zaktualizować injection | `analyze_case.rb` |
| **F4** | `GeneratorResolver`; controller demo flag; usunąć `ClientResolver` z HTTP | request spec dla notice | `generator_resolver.rb`, `debugging_cases_controller.rb` |
| **F5** | Test infrastructure: `Analysis::TestGenerators::*`; migracja stubów w request specs | security specs green | `spec/support/`, `spec/requests/*` |
| **F6** | Cleanup: rename `Request`→`ChatRequest`, `Client`→`ChatProvider`; usuń duplikat walidacji w starym path; deprecate `PromptBuilder.call` jeśli redundant | pełny `bin/ci` | `app/services/ai/*` |

**Nie w scope:** nowy provider (Anthropic), async analyze, prompt persistence.

### Przypadki testowe ACL

| # | Scenariusz | Warstwa | Oczekiwanie |
|---|------------|---------|-------------|
| A-L1 | `EvidenceBundle.from_debugging_case` z 2 sources | Analysis unit | Zawiera tylko `sanitized_content`; brak klucza `pasted_content` |
| A-L2 | `HypothesisGeneratorAdapter#generate` z FakeProvider | ACL unit | Zwraca `HypothesisReport` z hypotheses + uncertainty |
| A-L3 | AnalyzeCase end-to-end z injected generator | Service | `AiReport` generated; brak referencji do `Ai::` w orchestratorze |
| A-L4 | Request analyze — raw secret w intake | Request security | Prompt capture przez `CapturingGenerator`; raw absent |
| A-N1 | Invalid provider output 2× | Service | `ReportGenerationError` → failed report; `FAILURE_MESSAGE` |
| A-N2 | Grep guard (custom spec) | Meta | `app/services/analysis/` nie zawiera `Ai::` |
| A-N3 | Controller nie importuje `Ai::ClientResolver` | Request | Demo notice działa via `GeneratorResolver` |

### Load-bearing names (rejestr kontraktów)

| Nazwa | Rejestr |
|-------|---------|
| `Analysis::EvidenceBundle` | Ten dokument → po F1 wzmianka w `README.md` Architecture |
| `Analysis::HypothesisReport` | Ten dokument; mapuje PRD FR-008 |
| `Analysis::HypothesisGenerator` | Port — `test-plan.md` risk #2 (zamiast FakeClient capture) |
| `Analysis::ReportGenerationError` | Ten dokument |
| `Analysis::GeneratorResolver` | Zastępuje publiczny `Ai::ClientResolver` |
| `Ai::HypothesisGeneratorAdapter` | ACL facade — jedyny most Analysis↔Ai |
| `Ai::PromptTranslator` | Internal — Chat Completions mapping |
| `Ai::ChatRequest` | Internal (rename z `Ai::Request`) |
| `Ai::OpenAiChatProvider` | Internal (rename z `OpenAiClient`) |

---

## Diagram: przepływ before → after

```mermaid
flowchart TB
  subgraph before [Before — przeciek]
    PB1[PromptBuilder] --> AR1[Ai::Request]
    AC1[AnalyzeCase] --> CR1[Ai::ClientResolver]
    AC1 --> AR1
    AC1 --> CC1[client.complete]
    CTRL1[Controller] --> CR1
    CC1 --> OAI1[OpenAiClient / FakeClient]
  end

  subgraph after [After — ACL]
    AC2[AnalyzeCase] --> EB[EvidenceBundle]
    AC2 --> PORT[HypothesisGenerator port]
    PORT --> ADAPT[HypothesisGeneratorAdapter]
    ADAPT --> PT[PromptTranslator]
    PT --> CR2[ChatRequest internal]
    ADAPT --> OAI2[OpenAiChatProvider]
    CTRL2[Controller] --> GR[GeneratorResolver.demo_mode?]
  end
```

---

## Metadane

- **Wybrany przeciek #1:** kontrakt `Ai::` (Request/Client/CompletionResult/Errors/Resolver) w Analysis + HTTP
- **SDK OpenAI:** poprawnie izolowane — problem to brak ACL nad portem domenowym
- **Powiązanie:** uzupełnia `02-invariant-aggregate-refactor.md` (INV-G2 sanitized-only AI) — ACL wzmacnia egzekucję bez mieszania z intake aggregate
- **Nie weryfikowano:** pełna lista linii w każdym pliku spec poza grep; widoki poza `show.html.erb:17`
