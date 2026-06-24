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

    # Feedback callback_data shape: "fb:up:<notification_id>" / "fb:down:<id>".
    CALLBACK_PATTERN = /\Afb:(up|down):(\d+)\z/

    def self.call(...) = new(...).call

    def initialize(update, client: Telegram::Client.new, logger: Rails.logger)
      @update = update.is_a?(Hash) ? update.with_indifferent_access : {}
      @client = client
      @logger = logger
    end

    def call
      if (callback = @update[:callback_query]).present?
        handle_callback_query(callback)
      elsif (message = @update[:message]).present?
        handle_message(message)
      end
    rescue StandardError => error
      @logger.error("[Telegram::UpdateProcessor] #{error.class}: #{error.message}")
      nil
    end

    private

    def handle_message(message)
      if (contact = message[:contact]).present?
        handle_contact(message, contact)
      elsif (text = message[:text]).to_s.start_with?('/start')
        handle_start(message, text)
      end
    end

    # ---- callback_query (👍 / 👎 feedback) ----------------------------------

    def handle_callback_query(callback)
      action, notification_id = parse_feedback(callback[:data])
      return if action.nil?

      callback_id = callback[:id]
      from_id = callback.dig(:from, :id)
      notification = JobAlertNotification.find_by(id: notification_id)

      # A user may only act on their OWN notifications — the tapping Telegram user
      # (authenticated by Telegram) must own the alert behind this notification.
      unless owned_by?(notification, from_id)
        @logger.warn("[Telegram::UpdateProcessor] rejected callback from #{from_id} on notification #{notification_id}")
        return answer(callback_id, :not_authorized, alert: true)
      end
      return answer(callback_id, :already) if notification.feedback_given?

      record_message_id(notification, callback)
      action == 'up' ? handle_positive(notification, callback_id) : handle_negative(notification, callback_id, from_id)
    end

    def parse_feedback(data)
      match = data.to_s.match(CALLBACK_PATTERN)
      match ? [match[1], match[2].to_i] : [nil, nil]
    end

    def owned_by?(notification, from_id)
      return false if notification.nil? || from_id.blank?

      connection = TelegramConnection.linked.find_by(user_id: notification.user_id)
      connection&.telegram_user_id.present? && connection.telegram_user_id == from_id.to_i
    end

    def record_message_id(notification, callback)
      message_id = callback.dig(:message, :message_id)
      return if message_id.blank?

      notification.update_columns(telegram_message_id: message_id, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end

    def handle_positive(notification, callback_id)
      notification.record_feedback!('positive')
      answer(callback_id, :thanks)
      # Drop the feedback row so it can't be voted again.
      edit_keyboard(notification, JobAlerts::TelegramMessage.url_buttons(notification.job))
    end

    def handle_negative(notification, callback_id, from_id)
      notification.record_feedback!('negative')
      token = Telegram::FeedbackToken.generate(notification, telegram_user_id: from_id)
      answer(callback_id, :refine_prompt)
      url = Telegram::MiniApp.refine_url(token)
      edit_keyboard(notification, JobAlerts::TelegramMessage.refine_buttons(notification.job, url))
    end

    def edit_keyboard(notification, reply_markup)
      return if notification.telegram_message_id.blank?

      connection = TelegramConnection.linked.find_by(user_id: notification.user_id)
      return if connection&.telegram_chat_id.blank?

      @client.edit_message_reply_markup(
        chat_id: connection.telegram_chat_id, message_id: notification.telegram_message_id, reply_markup:
      )
    rescue Telegram::Client::Error => error
      @logger.warn("[Telegram::UpdateProcessor] keyboard edit failed: #{error.message}")
    end

    def answer(callback_id, key, alert: false)
      @client.answer_callback_query(
        callback_query_id: callback_id, text: I18n.t("telegram.feedback.#{key}"), show_alert: alert
      )
    end

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
