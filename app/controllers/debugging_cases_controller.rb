# frozen_string_literal: true

class DebuggingCasesController < AuthenticatedController
  include DebuggingCasesHelper

  def index
    @show_archived = params[:filter] == "archived"
    scope = @show_archived ? current_user.debugging_cases.archived : current_user.debugging_cases.active
    @debugging_cases = scope.includes(:log_sources, :ai_reports).order(created_at: :desc)
  end

  def new
    @title = @description = @customer_reference = @environment = nil
  end

  def show
    @debugging_case = current_user.debugging_cases.includes(log_sources: :redaction_findings).find(params[:id])
    @log_sources = @debugging_case.log_sources.order(:position)
    @findings = @log_sources.flat_map(&:redaction_findings)
    @correlation_signal = @debugging_case.correlation_signals.order(:created_at).last
    @correlation_signals = Correlation::ParsePayload.call(correlation_signal: @correlation_signal)
    @ai_report = @debugging_case.ai_reports.order(:created_at).last
    @ai_report_structured = Analysis::ParseStructuredReport.call(ai_report: @ai_report)
    @redaction_summary = Redaction::SummaryCounts.call(findings: @findings)
    @fake_ai_client_active = Ai::ClientResolver.fake_client_active?
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

  def download_report
    debugging_case = current_user.debugging_cases.find(params[:id])
    ai_report = debugging_case.ai_reports.generated.order(created_at: :desc).first

    if ai_report.nil? || ai_report.markdown_body.blank?
      head :not_found
      return
    end

    send_data ai_report.markdown_body,
              type: "text/markdown",
              disposition: "attachment",
              filename: Analysis::ReportFilename.call(debugging_case: debugging_case)
  end

  def archive
    debugging_case = current_user.debugging_cases.find(params[:id])
    debugging_case.archive!

    redirect_to debugging_cases_path, notice: "Case archived."
  end

  def load_demo
    unless Demo::LoadCase.available?
      head :not_found
      return
    end

    result = Demo::LoadCase.call(user: current_user)

    if result.success?
      redirect_to debugging_case_path(result.debugging_case), notice: "Demo case loaded."
    else
      redirect_to debugging_cases_path, alert: "Could not load demo case."
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

  # Re-populates case metadata only. Pasted log content is intentionally omitted on
  # validation failure — raw logs must not be re-rendered in HTML (AGENTS.md).
  def assign_safe_metadata_for_form
    permitted = case_submission_params
    @title = permitted[:title]
    @description = permitted[:description]
    @customer_reference = permitted[:customer_reference]
    @environment = permitted[:environment]
  end
end
