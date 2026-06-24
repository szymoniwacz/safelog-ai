# Intake parameter log filtering checklist

Raw intake values must never appear in Rails request logs. `config/initializers/filter_parameter_logging.rb` redacts matching keys before they are written to log files.

## When adding a new intake form field

1. Add the param key to `config/initializers/filter_parameter_logging.rb` (same symbol/string as the strong param).
2. Add the key to `INTAKE_PARAM_KEYS` in `spec/config/filter_parameter_logging_spec.rb`.
3. Run `mise exec -- bundle exec rspec spec/config/filter_parameter_logging_spec.rb`.

## Documented intake keys (keep in sync)

Case metadata (`DebuggingCasesController#case_submission_params`):

- `:title`
- `:description`
- `:customer_reference`
- `:environment`

Nested source fields (`sources[]`):

- `:pasted_content`

Also filtered for log paste safety (broader matchers): `:content`, `:raw`, `:log`, `:body`.

## Regression spec

`spec/config/filter_parameter_logging_spec.rb` uses `ActiveSupport::ParameterFilter` with `Rails.application.config.filter_parameters` to assert every documented intake key is redacted to `[FILTERED]`.
