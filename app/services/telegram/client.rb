# frozen_string_literal: true

require 'faraday'

module Telegram
  # Thin Faraday wrapper over the Telegram Bot API. Mirrors Jobs::HttpClient: it
  # centralises the base URL, timeouts and error handling so callers stay focused.
  class Client
    class Error < StandardError; end

    BASE_URL = 'https://api.telegram.org'
    TIMEOUT = 30
    # Update types we ask Telegram to deliver. callback_query carries inline-button
    # taps (👍/👎 feedback); message carries /start + shared contacts.
    ALLOWED_UPDATES = %w[message callback_query].freeze

    def initialize(token: Telegram.config.bot_token, logger: Rails.logger)
      @token = token
      @logger = logger
    end

    def send_message(chat_id:, text:, **)
      request('sendMessage', chat_id:, text:, parse_mode: 'HTML', disable_web_page_preview: true, **)
    end

    # Acknowledges an inline-button tap so Telegram stops the button spinner. The
    # optional text is shown to the user as a toast (or alert when show_alert).
    def answer_callback_query(callback_query_id:, text: nil, show_alert: false)
      request('answerCallbackQuery', callback_query_id:, text:, show_alert:)
    end

    # Replaces the inline keyboard on an already-sent message.
    def edit_message_reply_markup(chat_id:, message_id:, reply_markup:)
      request('editMessageReplyMarkup', chat_id:, message_id:, reply_markup:)
    end

    def set_webhook(url:, secret_token: nil)
      request('setWebhook', url:, secret_token:, allowed_updates: ALLOWED_UPDATES)
    end

    def delete_webhook
      request('deleteWebhook')
    end

    def get_updates(offset: nil, timeout: 25)
      request('getUpdates', offset:, timeout:, allowed_updates: ALLOWED_UPDATES)
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
