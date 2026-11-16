# frozen_string_literal: true

module Api
  module MCP
    class QuestionsController < BaseController
      MAX_QUESTION_LENGTH = 500

      # POST /api/mcp/questions
      def create
        question = params.expect(:question).to_s.strip
        if question.empty? || question.length > MAX_QUESTION_LENGTH
          return render json: { error: "question must be 1-#{MAX_QUESTION_LENGTH} characters" }, status: :unprocessable_content
        end

        started = Time.current
        answer = bridge.ask(question)
        render json: {
          question: question,
          answer: answer,
          tools_used: bridge.tools_used,
          model: bridge.model,
          duration_ms: ((Time.current - started) * 1000).round
        }, status: :created
      rescue *UNREACHABLE_ERRORS, ::MCP::OllamaBridge::Error => e
        render_mcp_error(e)
      end
    end
  end
end
