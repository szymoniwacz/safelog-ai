# frozen_string_literal: true

module RequestStatusHelpers
  def expect_not_found_without_forbidden
    expect(response).to have_http_status(:not_found)
    expect(response).not_to have_http_status(:forbidden)
  end
end
