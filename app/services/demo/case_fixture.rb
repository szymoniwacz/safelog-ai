# frozen_string_literal: true

module Demo
  module CaseFixture
    DEMO_EMAIL = "checkout-demo@example.com"
    DEMO_TOKEN = "sk-demo-checkout-token-not-real"
    DEMO_REQUEST_ID = "req-demo-checkout-1"

    def self.submission_attributes
      {
        title: "Checkout payment timeout (demo)",
        description: "Demo case: payment step hangs after authorization.",
        customer_reference: "Demo ticket — request_id=#{DEMO_REQUEST_ID}",
        environment: "production",
        sources: [
          {
            source_type: "rails_log",
            name: "Rails",
            pasted_content: <<~LOG.strip
              Started POST /checkout request_id=#{DEMO_REQUEST_ID}
              Checkout failed for #{DEMO_EMAIL}
              Authorization: Bearer #{DEMO_TOKEN}
            LOG
          },
          {
            source_type: "aws_cloudwatch",
            name: "CloudWatch",
            pasted_content: <<~LOG.strip
              Payment gateway timeout waiting for request_id=#{DEMO_REQUEST_ID} after 30000ms
            LOG
          },
          {
            source_type: "browser_console",
            name: "Browser console",
            pasted_content: "CheckoutError: timeout for request_id=#{DEMO_REQUEST_ID}"
          }
        ]
      }
    end
  end
end
