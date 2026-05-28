# frozen_string_literal: true

module Redaction
  module Patterns
    # PRD MVP detectors — heuristic regexes, not exhaustive DLP.
    #
    # Known gaps (accepted for MVP; extend here rather than ad-hoc regex elsewhere):
    # - Standalone API keys (e.g. bare sk-… on a line without "token=" or
    #   Authorization: Bearer) are not matched; use labeled token= / Bearer forms
    #   in fixtures and course demos, or add a dedicated pattern when needed.
    ALL = [
      {
        finding_type: "authorization_header",
        placeholder_type: "AUTH",
        risk_level: "high",
        regex: /Authorization:\s*Bearer\s+\S+/i
      },
      {
        finding_type: "email",
        placeholder_type: "EMAIL",
        risk_level: "high",
        regex: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/
      },
      {
        finding_type: "request_id",
        placeholder_type: "REQUEST",
        risk_level: "medium",
        regex: /\b(?:request[_-]?id|req[_-]?id)\s*[=:]\s*["']?([A-Za-z0-9-]{4,})["']?/i
      },
      {
        finding_type: "session_id",
        placeholder_type: "SESSION",
        risk_level: "high",
        regex: /\b(?:session[_-]?id|sid)\s*[=:]\s*["']?([A-Za-z0-9-]{4,})["']?/i
      },
      {
        finding_type: "customer_id",
        placeholder_type: "CUSTOMER",
        risk_level: "high",
        regex: /\b(?:customer[_-]?id|cust[_-]?id)\s*[=:]\s*["']?([A-Za-z0-9-]{3,})["']?/i
      },
      {
        finding_type: "ip_address",
        placeholder_type: "IP",
        risk_level: "medium",
        regex: /\b(?:\d{1,3}\.){3}\d{1,3}\b/
      },
      {
        finding_type: "phone",
        placeholder_type: "PHONE",
        risk_level: "medium",
        regex: /\b(?:\+?1[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b/
      },
      {
        finding_type: "card_last4",
        placeholder_type: "CARD",
        risk_level: "high",
        regex: /\b(?:card(?:\s+ending|\s+last4)?|\*{4,})\s*#?\s*(\d{4})\b/i
      },
      {
        finding_type: "token",
        placeholder_type: "TOKEN",
        risk_level: "high",
        regex: /\b(?:api[_-]?key|token|secret)\s*[=:]\s*["']?([A-Za-z0-9._-]{8,})["']?/i
      }
    ].freeze
  end
end
