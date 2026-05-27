# F-02/S-02 and other app pages must inherit AuthenticatedController, not ApplicationController.
# Do not add authenticate_user! globally here — per-controller gating stays explicit.
# Request-spec auth coverage for session gating lands in S-01; cross-user case isolation in S-02.
class AuthenticatedController < ApplicationController
  before_action :authenticate_user!
end
