class LogSource < ApplicationRecord
  belongs_to :debugging_case

  encrypts :sanitized_content

  enum :source_type, {
    rails_log: "rails_log",
    aws_cloudwatch: "aws_cloudwatch",
    new_relic: "new_relic",
    browser_console: "browser_console",
    customer_report: "customer_report",
    other: "other"
  }
end
