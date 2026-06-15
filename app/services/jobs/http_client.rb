# frozen_string_literal: true

require 'faraday'
require 'faraday/retry'

module Jobs
  # Thin Faraday wrapper shared by the job scrapers. Centralises the user-agent,
  # timeouts, and retry policy so each source scraper stays focused on parsing.
  class HttpClient
    class Error < StandardError; end

    USER_AGENT = 'ResumeETJobBot/1.0 (+https://resume.et; jobs aggregator)'
    DEFAULT_TIMEOUT = 25
    OPEN_TIMEOUT = 10

    RETRY_OPTIONS = {
      max: 3,
      interval: 1,
      interval_randomness: 0.5,
      backoff_factor: 2,
      retry_statuses: [429, 500, 502, 503, 504],
      methods: %i[get post]
    }.freeze

    def initialize(timeout: DEFAULT_TIMEOUT)
      @conn = Faraday.new do |f|
        f.request :retry, **RETRY_OPTIONS
        f.headers['User-Agent'] = USER_AGENT
        f.options.timeout = timeout
        f.options.open_timeout = OPEN_TIMEOUT
        f.adapter Faraday.default_adapter
      end
    end

    def get(url, headers: {})
      response = @conn.get(url) { |req| req.headers.update(headers) }
      ensure_success!(response, url)
      response.body
    rescue Faraday::Error => error
      raise Error, "GET #{url} failed: #{error.message}"
    end

    # POSTs a JSON body and parses the JSON response. Used for the hahu.jobs
    # GraphQL endpoint.
    def post_json(url, payload, headers: {})
      response = @conn.post(url) do |req|
        req.headers['Content-Type'] = 'application/json'
        req.headers.merge!(headers)
        req.body = payload.to_json
      end
      ensure_success!(response, url)
      JSON.parse(response.body)
    rescue Faraday::Error => error
      raise Error, "POST #{url} failed: #{error.message}"
    rescue JSON::ParserError => error
      raise Error, "POST #{url} returned invalid JSON: #{error.message}"
    end

    private

    def ensure_success!(response, url)
      return if response.success?

      raise Error, "#{url} responded with HTTP #{response.status}"
    end
  end
end
