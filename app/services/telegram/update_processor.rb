# frozen_string_literal: true

module Telegram
  # Processes a single inbound Telegram update (from the webhook or the dev poller).
  #
  # Two messages matter for account linking:
  #   1. "/start <token>" — resolve the deep-link token to a pending connection,
  #      store the chat_id, and ask the user to share their phone number.
  #   2. a shared contact — verify it is an Ethiopian (+251) number and finalise
  #      the link.
  # Everything else is ignored. Errors are swallowed (logged) so a malformed
  # update never bubbles up to the webhook.
  class UpdateProcessor
    # +2519XXXXXXXX / +2517XXXXXXXX (mobile) — 12 digits after the plus.
    ETHIOPIAN_PHONE = /\A\+251[79]\d{8}\z/

    MESSAGES = {
      invalid_link: '⚠️ This link is invalid or has expired. Open the “Connect Telegram” ' \
                    'button in Resume.et again to get a fresh link.',
      share_phone: 'Almost there! Tap the button below to share your phone number so we can ' \
                   'verify your account and start sending you job alerts.',
      share_own: '⚠️ Please share *your own* contact using the button below, not another contact.',
      invalid_phone: '⚠️ That does not look like an Ethiopian (+251) phone number. Please share ' \
                     'the phone number registered with this Telegram account.',
      linked: '✅ Your Telegram is connected! You will now receive matching job alerts here.'
    }.freeze

    def self.call(...) = new(...).call

    def initialize(update, client: Telegram::Client.new, logger: Rails.logger)
      @update = update.is_a?(Hash) ? update.with_indifferent_access : {}
      @client = client
      @logger = logger
    end

    def call
      message = @update[:message]
      return if message.blank?

      if (contact = message[:contact]).present?
        handle_contact(message, contact)
      elsif (text = message[:text]).to_s.start_with?('/start')
        handle_start(message, text)
      end
    rescue StandardError => error
      @logger.error("[Telegram::UpdateProcessor] #{error.class}: #{error.message}")
      nil
    end

    private

    def handle_start(message, text)
      chat_id = message.dig(:chat, :id)
      token = text.to_s.split(/\s+/, 2)[1].to_s.strip
      connection = token.present? ? TelegramConnection.find_by(link_token: token) : nil

      unless connection&.link_token_valid?
        @client.send_message(chat_id:, text: MESSAGES[:invalid_link])
        return
      end

      from = message[:from] || {}
      connection.update!(
        telegram_chat_id: chat_id,
        telegram_user_id: from[:id],
        telegram_username: from[:username]
      )
      @client.send_message(chat_id:, text: MESSAGES[:share_phone], reply_markup: contact_keyboard)
    end

    def handle_contact(message, contact)
      chat_id = message.dig(:chat, :id)
      connection = TelegramConnection.find_by(telegram_chat_id: chat_id)
      return if connection.blank?

      if shared_someone_else?(connection, contact)
        @client.send_message(chat_id:, text: MESSAGES[:share_own])
        return
      end

      phone = normalize_phone(contact[:phone_number])
      unless phone&.match?(ETHIOPIAN_PHONE)
        @client.send_message(chat_id:, text: MESSAGES[:invalid_phone])
        return
      end

      connection.update!(
        phone_number: phone, phone_verified: true, status: :linked, linked_at: Time.current,
        link_token: nil, link_token_expires_at: nil
      )
      @client.send_message(chat_id:, text: MESSAGES[:linked], reply_markup: { remove_keyboard: true })
    end

    def shared_someone_else?(connection, contact)
      contact[:user_id].present? && connection.telegram_user_id.present? &&
        contact[:user_id].to_i != connection.telegram_user_id
    end

    # Normalises Ethiopian numbers to E.164 (+251XXXXXXXXX). Telegram usually sends
    # the number without a leading "+"; handle the common local formats too.
    def normalize_phone(raw)
      digits = raw.to_s.gsub(/[^\d]/, '')
      return if digits.blank?

      digits = "251#{digits[1..]}" if digits.start_with?('0')
      digits = "251#{digits}" if digits.length == 9 # bare 9XXXXXXXX / 7XXXXXXXX
      "+#{digits}"
    end

    def contact_keyboard
      {
        keyboard: [[{ text: '📱 Share my phone number', request_contact: true }]],
        resize_keyboard: true,
        one_time_keyboard: true
      }
    end
  end
end
