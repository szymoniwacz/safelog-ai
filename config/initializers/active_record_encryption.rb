# frozen_string_literal: true

# Development/test: Active Record Encryption keys come from credentials
# (`active_record_encryption`) when config/master.key is present. CI/test without
# credentials uses RAILS_ACTIVE_RECORD_ENCRYPTION_* env vars — see
# config/environments/test.rb and .github/workflows/ci.yml.
#
# Generate a credentials snippet with:
#   mise exec -- bin/rails db:encryption:init
# then merge into credentials via `mise exec -- bin/rails credentials:edit`.
#
# Production (Fly): RAILS_ACTIVE_RECORD_ENCRYPTION_* env vars — see
# config/environments/production.rb and context/deployment/deploy-plan.md.
