# frozen_string_literal: true

require 'base64'

module Resumes
  # Google Gemini-backed resume parser. Uses gemini-2.5-flash-lite — the cheapest
  # production Gemini model that supports document/vision input — via the
  # Generative Language API (AI Studio) with a plain API key.
  #
  # The PDF/image goes inline as base64 (fine for the importer's 10 MB cap, well
  # under Gemini's 20 MB inline limit). We force a JSON response with
  # response_mime_type so the model can't wrap it in prose/fences. Shared
  # JSON/sanitization logic lives in Resumes::BaseResumeParser; prompt text in
  # Resumes::ResumeParser::Prompt.
  class GeminiResumeParser < BaseResumeParser
    MODEL = 'gemini-2.5-flash-lite'
    TIMEOUT_SECONDS = 120
    # gemini-2.5-flash-lite intermittently returns 503 UNAVAILABLE ("high demand")
    # and occasionally 429/5xx. The gemini-ai gem does not retry (unlike the
    # official Anthropic SDK), so we retry these transient failures ourselves.
    MAX_ATTEMPTS = 4
    RETRYABLE_STATUSES = [429, 500, 502, 503, 504].freeze
    RETRY_BASE_DELAY = 0.5
    # A resume's worth of JSON is well under this; the cap only guards against a
    # runaway generation (every output token is billed).
    MAX_OUTPUT_TOKENS = 8_192

    private

    def request
      with_retries { client.generate_content(payload, server_sent_events: false) }
    rescue StandardError => e
      raise ImportError, "Resume parsing service error: #{e.message}"
    end

    def with_retries
      attempt = 0
      begin
        attempt += 1
        yield
      rescue StandardError => e
        raise unless attempt < MAX_ATTEMPTS && transient?(e)

        sleep(retry_delay(attempt))
        retry
      end
    end

    # Transient = a retryable HTTP status from the API, or a timeout/connection
    # blip (which the gem leaves as a raw Faraday error rather than wrapping).
    def transient?(error)
      case error
      when Gemini::Errors::RequestError
        RETRYABLE_STATUSES.include?(response_status(error.request))
      when Faraday::TimeoutError, Faraday::ConnectionFailed
        true
      else
        false
      end
    end

    def response_status(faraday_error)
      faraday_error.response_status if faraday_error.respond_to?(:response_status)
    end

    # Exponential backoff (0.5s, 1s, 2s …) with a little jitter to avoid syncing
    # retries when Gemini is briefly overloaded.
    def retry_delay(attempt)
      (RETRY_BASE_DELAY * (2**(attempt - 1))) + (rand * RETRY_BASE_DELAY)
    end

    # Cost-minimized generation config for a pure extraction task:
    # - thinking_budget 0 disables 2.5's "thinking", which otherwise bills reasoning
    #   tokens we don't need (the single biggest avoidable cost on 2.5 models).
    # - temperature 0 makes extraction deterministic — better accuracy and a stable
    #   output for the same input, which keeps the result cache effective.
    # - response_mime_type pins JSON so no tokens are spent on prose/fences.
    # - max_output_tokens caps a pathological run.
    #
    # System-prompt context caching is deliberately not used: the only reusable
    # prefix (the ~845-token system prompt) is below flash-lite's 1024-token cache
    # minimum, and the per-resume document is unique. Reuse is handled instead by
    # the content-hash result cache in Resumes::BaseResumeParser.
    def payload
      {
        contents: { role: 'user', parts: [{ text: ResumeParser::Prompt::USER }, document_part] },
        system_instruction: { role: 'user', parts: [{ text: ResumeParser::Prompt::SYSTEM }] },
        generation_config: {
          temperature: 0,
          max_output_tokens: MAX_OUTPUT_TOKENS,
          response_mime_type: 'application/json',
          thinking_config: { thinking_budget: 0 }
        }
      }
    end

    def document_part
      { inline_data: { mime_type: @media_type, data: Base64.strict_encode64(@data) } }
    end

    # The Generative Language API returns string keys; concatenate every text
    # part of the first candidate (usually one) so a split response still parses.
    def extract_text(response)
      parts = response.dig('candidates', 0, 'content', 'parts')
      text = Array(parts).filter_map { |part| part['text'] }.join
      raise ImportError, 'The parser returned no readable content.' if text.blank?

      text
    end

    # version: 'v1beta' is required — the gem defaults to the stable 'v1' endpoint,
    # which rejects system_instruction / response_mime_type and the gemini-2.5
    # model family (HTTP 400, "Unknown name ... Cannot find field").
    def client
      @client ||= Gemini.new(
        credentials: { service: 'generative-language-api', api_key: ENV.fetch('GEMINI_API_KEY'), version: 'v1beta' },
        options: { model: MODEL, server_sent_events: false, connection: { request: { timeout: TIMEOUT_SECONDS } } }
      )
    end
  end
end
