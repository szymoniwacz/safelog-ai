# frozen_string_literal: true

module Ai
  module Client
    def complete(_request)
      raise NotImplementedError, "#{self.class} must implement #complete"
    end
  end
end
