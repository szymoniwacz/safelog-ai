# frozen_string_literal: true

module AiTestClients
  class InvalidOnceClient
    include Ai::Client

    attr_reader :complete_calls, :last_request

    def initialize
      @complete_calls = 0
      @fallback = Ai::FakeClient.new
    end

    def complete(request)
      @complete_calls += 1
      @last_request = request

      if @complete_calls == 1
        Ai::CompletionResult.new(structured: { summary: "" }, markdown: "")
      else
        @fallback.complete(request)
      end
    end
  end

  class InvalidClient
    include Ai::Client

    attr_reader :complete_calls, :last_request

    def initialize
      @delegate = Ai::InvalidClient.new
    end

    def complete(request)
      result = @delegate.complete(request)
      @complete_calls = @delegate.complete_calls
      @last_request = @delegate.last_request
      result
    end
  end
end
