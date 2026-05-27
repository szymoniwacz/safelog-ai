class RedactionFinding < ApplicationRecord
  belongs_to :log_source

  validates :finding_type, :line_number, :placeholder, :risk_level, presence: true
end
