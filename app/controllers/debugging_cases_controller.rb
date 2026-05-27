# frozen_string_literal: true

class DebuggingCasesController < AuthenticatedController
  include DebuggingCasesHelper

  def new
    @title = @description = @customer_reference = @environment = nil
  end

  def show
    @debugging_case = current_user.debugging_cases.includes(log_sources: :redaction_findings).find(params[:id])
    @log_sources = @debugging_case.log_sources.order(:position)
    @findings = @log_sources.flat_map(&:redaction_findings)
    @correlation_signal = @debugging_case.correlation_signals.order(:created_at).last
    @correlation_signals = parse_correlation_signals(@correlation_signal)
    @ai_report = @debugging_case.ai_reports.order(:created_at).last
    @ai_report_structured = parse_ai_report_structured(@ai_report)
  end

  def create
    submission = Intake::CaseSubmission.new(case_submission_params)
    result = Intake::ProcessCaseSubmission.call(user: current_user, submission: submission)

    if result.success?
      redirect_to debugging_case_path(result.debugging_case)
    else
      assign_safe_metadata_for_form
      @errors = result.errors
      render :new, status: :unprocessable_entity
    end
  end

  def analyze
    debugging_case = current_user.debugging_cases.find(params[:id])
    result = Analysis::AnalyzeCase.call(debugging_case: debugging_case)

    if result.success?
      redirect_to debugging_case_path(debugging_case), notice: "Analysis complete."
    else
      redirect_to debugging_case_path(debugging_case), alert: result.user_message
    end
  end

  private

  def case_submission_params
    params.require(:debugging_case).permit(
      :title,
      :description,
      :customer_reference,
      :environment,
      sources: [ :source_type, :name, :pasted_content ]
    )
  end

  def assign_safe_metadata_for_form
    permitted = case_submission_params
    @title = permitted[:title]
    @description = permitted[:description]
    @customer_reference = permitted[:customer_reference]
    @environment = permitted[:environment]
  end
end
