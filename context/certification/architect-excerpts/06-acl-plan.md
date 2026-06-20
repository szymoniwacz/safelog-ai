# Anti-Corruption Layer Plan — SafeLog AI

DDD plan (no production code implementation in Module 4). Source: `context/domain/03-anti-corruption-layer.md`

---

## Step 4 — ACL design

### Context split

```
┌─────────────────────────────────────────────┐
│ Analysis (domain)                           │
│  EvidenceBundle, HypothesisReport (VO)      │
│  HypothesisGenerator (PORT)               │
│  AnalyzeCase (orchestrator — PORT only)   │
└──────────────────┬──────────────────────────┘
                   │ port
┌──────────────────▼──────────────────────────┐
│ Ai (ACL + infrastructure)                   │
│  HypothesisGeneratorAdapter (facade)        │
│  PromptTranslator → ChatRequest (internal)  │
│  OpenAiChatProvider (OpenAI::Client)        │
│  FakeHypothesisProvider                     │
│  ResponseValidator, ReportSchema (internal) │
└─────────────────────────────────────────────┘
```

### Domain value objects (Analysis — only place that knows *what* we send/receive)

```ruby
module Analysis
  class EvidenceBundle
    # Sanitized evidence package — zero knowledge of Chat Completions API
    def self.from_debugging_case(debugging_case:, correlation_payload:)
      # maps AR → immutable structs (source_type, name, sanitized_content, position)
    end
  end

  class HypothesisReport
    # Hypothesis-framed report — PRD FR-008 contract, not provider JSON shape
    attr_reader :summary, :hypotheses, :uncertainty_notes, :correlation_highlights
  end

  class ReportGenerationError < StandardError; end  # port failure — not Ai::InvalidResponseError
end
```

### Narrow port (domain interface)

```ruby
module Analysis
  module HypothesisGenerator
    # @param evidence [EvidenceBundle]
    # @return [HypothesisReport]
    # @raise [ReportGenerationError]
    def generate(evidence:)
      raise NotImplementedError
    end
  end
end
```

All other code (`AnalyzeCase`, controller, views) knows **only** `HypothesisGenerator` and `HypothesisReport`.

### ACL adapter implementing the port

```ruby
module Ai
  class HypothesisGeneratorAdapter
    include Analysis::HypothesisGenerator

    def generate(evidence:)
      chat_request = PromptTranslator.to_chat_request(evidence)
      raw = @provider.complete(chat_request)
      ResponseTranslator.to_hypothesis_report(raw, validator: @validator)
    end
  end
end
```

**Leak fixed:** `AnalyzeCase` no longer imports OpenAI types or parses provider JSON — adapter translates at the boundary.

**Plan status:** F1–F6 phased roadmap documented for future implementation slice — M4L5 deliverable complete.
