# F-02 schema root. Intake/redaction: S-02. AI adapter: F-03. HTTP: inherit AuthenticatedController.
class DebuggingCase < ApplicationRecord
  belongs_to :user

  encrypts :customer_reference

  has_many :log_sources, dependent: :destroy
  has_many :correlation_signals, dependent: :destroy
  has_many :ai_reports, dependent: :destroy

  validates :title, presence: true

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  def archived?
    archived_at.present?
  end

  def archive!
    return if archived?

    update!(archived_at: Time.current)
  end

  def latest_ai_report
    ai_reports.max_by(&:created_at)
  end

  def analysis_status
    report = latest_ai_report
    return :not_analyzed if report.nil?

    case report.status
    when "generated" then :analyzed
    when "failed" then :failed
    else :in_progress
    end
  end
end
