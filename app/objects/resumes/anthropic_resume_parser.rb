# frozen_string_literal: true

require 'base64'

module Resumes
  # Anthropic-backed resume parser. Uses claude-haiku-4-5 — the cheapest Claude
  # model that supports document/vision input. Shared JSON/sanitization logic
  # lives in Resumes::BaseResumeParser; prompt text in Resumes::ResumeParser::Prompt.
  class AnthropicResumeParser < BaseResumeParser
    MODEL = 'claude-haiku-4-5'
    MAX_TOKENS = 8_000
    TIMEOUT_SECONDS = 120

    private

    def request
      client.messages.create( # rubocop:disable Rails/SaveBang -- Anthropic SDK call, not ActiveRecord
        model: MODEL,
        max_tokens: MAX_TOKENS,
        system_: [{ type: 'text', text: ResumeParser::Prompt::SYSTEM, cache_control: { type: 'ephemeral' } }],
        messages: [{ role: 'user', content: content_blocks }]
      )
    rescue StandardError => e
      raise ImportError, "Resume parsing service error: #{e.message}"
    end

    def content_blocks
      [document_block, { type: 'text', text: ResumeParser::Prompt::USER }]
    end

    def document_block
      encoded = Base64.strict_encode64(@data)
      source = { type: 'base64', media_type: @media_type, data: encoded }

      if @media_type == 'application/pdf'
        { type: 'document', source: source }
      else
        { type: 'image', source: source }
      end
    end

    def extract_text(response)
      block = response.content.find { |item| item.type.to_s == 'text' }
      raise ImportError, 'The parser returned no readable content.' if block.nil?

      block.text
    end

    def client
      @client ||= Anthropic::Client.new(api_key: ENV.fetch('ANTHROPIC_API_KEY'), timeout: TIMEOUT_SECONDS)
    end
  end
end
