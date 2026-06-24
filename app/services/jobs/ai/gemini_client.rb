# frozen_string_literal: true

require 'json'

module Jobs
  module Ai
    # Thin wrapper around the gemini-ai gem for the job pipeline, mirroring the
    # cost-conscious configuration of Resumes::GeminiResumeParser:
    # gemini-2.5-flash-lite, thinking disabled (thinking_budget 0), temperature 0,
    # forced JSON output, a tight output-token cap, and in-process retries on the
    # transient (429/5xx/timeout) failures the gem does not retry itself.
    #
    # Unlike the resume parser this sends text-only prompts (no inline documents),
    # so the payload stays small and cheap.
    class GeminiClient
      class Error < StandardError; end

      MODEL = 'gemini-2.5-flash-lite'
      TIMEOUT_SECONDS = 60
      MAX_ATTEMPTS = 4
      RETRYABLE_STATUSES = [429, 500, 502, 503, 504].freeze
      RETRY_BASE_DELAY = 0.5

      def self.configured?
        ENV['GEMINI_API_KEY'].present?
      end

      def initialize(client: nil, logger: Rails.logger)
        @client = client
        @logger = logger
      end

      # @return [Hash] the parsed JSON object the model returned
      # @raise [Error] on a non-transient failure or unreadable output
      def generate_json(system:, user:, max_output_tokens:)
        response = with_retries do
          client.generate_content(payload(system, user, max_output_tokens), server_sent_events: false)
        end
        parse(extract_text(response))
      rescue Gemini::Errors::RequestError, Faraday::Error => e
        raise Error, "Gemini request failed: #{e.message}"
      end

      private

      attr_reader :logger

      # Cost-minimized generation config (see Resumes::GeminiResumeParser for the
      # rationale behind each knob).
      def payload(system, user, max_output_tokens)
        {
          contents: { role: 'user', parts: [{ text: user }] },
          system_instruction: { role: 'user', parts: [{ text: system }] },
          generation_config: {
            temperature: 0,
            max_output_tokens:,
            response_mime_type: 'application/json',
            thinking_config: { thinking_budget: 0 }
          }
        }
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

      def retry_delay(attempt)
        (RETRY_BASE_DELAY * (2**(attempt - 1))) + (rand * RETRY_BASE_DELAY)
      end

      def parse(text)
        JSON.parse(strip_fences(text))
      rescue JSON::ParserError => e
        raise Error, "Gemini returned unreadable JSON: #{e.message}"
      end

      # The Generative Language API returns string keys; join every text part of
      # the first candidate so a split response still parses.
      def extract_text(response)
        parts = response.dig('candidates', 0, 'content', 'parts')
        text = Array(parts).filter_map { |part| part['text'] }.join
        raise Error, 'Gemini returned no content' if text.blank?

        text
      end

      # Defensive: response_mime_type pins JSON, but strip ```json fences if present.
      def strip_fences(text)
        text.to_s.strip.sub(/\A```(?:json)?\s*/i, '').delete_suffix('```').strip
      end

      # version: 'v1beta' is required for system_instruction / response_mime_type
      # and the gemini-2.5 model family (see Resumes::GeminiResumeParser).
      def client
        @client ||= Gemini.new(
          credentials: { service: 'generative-language-api', api_key: ENV.fetch('GEMINI_API_KEY'), version: 'v1beta' },
          options: { model: MODEL, server_sent_events: false, connection: { request: { timeout: TIMEOUT_SECONDS } } }
        )
      end
    end
  end
end
