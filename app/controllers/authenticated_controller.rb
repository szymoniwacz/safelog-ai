# Domain controllers (debugging cases, etc.) must inherit this class — not ApplicationController.
class AuthenticatedController < ApplicationController
  before_action :authenticate_user!
end
