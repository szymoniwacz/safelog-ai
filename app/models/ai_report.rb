class AiReport < ApplicationRecord
  belongs_to :debugging_case

  encrypts :structured_json, :markdown_body

  enum :status, {
    pending: "pending",
    processing: "processing",
    generated: "generated",
    failed: "failed"
  }, default: :pending
end
