# frozen_string_literal: true

require 'faraday'

module Telegram
  # Thin Faraday wrapper over the Telegram Bot API. Mirrors Jobs::HttpClient: it
  # centralises the base URL, timeouts and error handling so callers stay focused.
  class Client
    class Error < StandardError; end

    BASE_URL = 'https://api.telegram.org'
    TIMEOUT = 30

    def initialize(token: Telegram.config.bot_token, logger: Rails.logger)
      @token = token
      @logger = logger
    end

    def send_message(chat_id:, text:, **)
      request('sendMessage', chat_id:, text:, parse_mode: 'HTML', disable_web_page_preview: true, **)
    end

    def set_webhook(url:, secret_token: nil)
      request('setWebhook', url:, secret_token:, allowed_updates: %w[message])
    end

    def delete_webhook
      request('deleteWebhook')
    end

    def get_updates(offset: nil, timeout: 25)
      request('getUpdates', offset:, timeout:, allowed_updates: %w[message])
    end

    private

    attr_reader :logger

    def request(method, **payload)
      raise Error, 'Telegram bot token is not configured' if @token.blank?

      response = connection.post("/bot#{@token}/#{method}", payload.compact)
      body = JSON.parse(response.body)
      raise Error, "Telegram #{method} failed: #{body['description']}" unless body['ok']

      body['result']
    rescue Faraday::Error => error
      raise Error, "Telegram #{method} request failed: #{error.message}"
    rescue JSON::ParserError => error
      raise Error, "Telegram #{method} returned invalid JSON: #{error.message}"
    end

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.options.timeout = TIMEOUT
        f.options.open_timeout = 10
        f.adapter Faraday.default_adapter
      end
    end
  end
end
