# F-02 schema root. Intake/redaction: S-02. AI adapter: F-03. HTTP: inherit AuthenticatedController.
class DebuggingCase < ApplicationRecord
  belongs_to :user

  encrypts :customer_reference

  has_many :log_sources, dependent: :destroy
  has_many :correlation_signals, dependent: :destroy
  has_many :ai_reports, dependent: :destroy

  validates :title, presence: true
end
