# F-02/S-02 and other app pages must inherit AuthenticatedController, not ApplicationController.
# Do not add authenticate_user! globally here — per-controller gating stays explicit.
# Request-spec auth coverage (user A cannot access user B) lands in S-01 (account-access).
class AuthenticatedController < ApplicationController
  before_action :authenticate_user!
end
