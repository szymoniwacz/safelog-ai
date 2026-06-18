# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Debugging cases index", type: :request do
  let(:user) { create(:user, email: "index@example.com") }
  let(:other_user) { create(:user, email: "other-index@example.com") }

  def create_case(title:, user: self.user)
    Intake::ProcessCaseSubmission.call(
      user: user,
      submission: Intake::CaseSubmission.new(
        title: title,
        environment: "production",
        sources: [ { source_type: "rails_log", pasted_content: "ok" } ]
      )
    ).debugging_case
  end

  let!(:active_case) { create_case(title: "Active checkout case") }
  let!(:archived_case) do
    create_case(title: "Archived timeout case").tap(&:archive!)
  end

  describe "GET /debugging_cases" do
    it "redirects guests to sign in" do
      get debugging_cases_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists active cases by default" do
      sign_in user

      get debugging_cases_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Active checkout case")
      expect(response.body).not_to include("Archived timeout case")
    end

    it "lists archived cases when the archived filter is selected" do
      sign_in user

      get debugging_cases_path(filter: "archived")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Archived timeout case")
      expect(response.body).not_to include("Active checkout case")
    end

    it "does not list another user's cases on the active index" do
      other_case = create_case(title: "Other user private case", user: other_user)

      sign_in user

      get debugging_cases_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(other_case.title)
    end

    it "does not list another user's cases on the archived index" do
      other_case = create_case(title: "Other user archived case", user: other_user)
      other_case.archive!

      sign_in user

      get debugging_cases_path(filter: "archived")

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(other_case.title)
    end

    it "shows source count and analysis status for each case" do
      active_case.ai_reports.create!(status: :generated, markdown_body: "# Report")

      sign_in user

      get debugging_cases_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("1 source")
      expect(response.body).to include("Analyzed")
      expect(response.body).to include('class="status-badge status-badge--success"')
    end

    it "shows not analyzed when the case has no AI report" do
      sign_in user

      get debugging_cases_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Not analyzed")
    end
  end
end
