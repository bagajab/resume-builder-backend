# frozen_string_literal: true

module JobAlerts
  # Delivers a single instant-frequency notification over Telegram. Transient
  # Telegram failures are retried; after the final attempt the notification is
  # marked `failed` so the delivery log stays accurate.
  class DeliverNotificationJob < ApplicationJob
    queue_as :default

    discard_on ActiveJob::DeserializationError

    retry_on Telegram::Client::Error, wait: :polynomially_longer, attempts: 5 do |job, error|
      notification_id = job.arguments.first
      JobAlertNotification.where(id: notification_id).update_all( # rubocop:disable Rails/SkipsModelValidations
        status: JobAlertNotification.statuses[:failed], error: error.message, updated_at: Time.current
      )
    end

    def perform(notification_id)
      notification = JobAlertNotification.includes(:job).find_by(id: notification_id)
      return if notification.nil? || notification.sent?

      chat_id = linked_chat_id(notification)
      return if chat_id.nil?

      deliver(notification, chat_id)
    end

    private

    def deliver(notification, chat_id)
      result = Telegram::Client.new.send_message(
        chat_id:,
        text: JobAlerts::TelegramMessage.single(notification.job),
        reply_markup: JobAlerts::TelegramMessage.single_buttons(notification)
      )
      # Keep the delivered message id so a later 👍/👎 tap can edit its keyboard.
      message_id = result.is_a?(Hash) ? result['message_id'] : nil
      notification.update!(status: :sent, sent_at: Time.current, error: nil, telegram_message_id: message_id)
    end

    # Returns the user's Telegram chat id, or nil after marking the notification
    # skipped when there's nowhere to deliver it.
    def linked_chat_id(notification)
      connection = TelegramConnection.linked.find_by(user_id: notification.user_id)
      return connection.telegram_chat_id if connection&.telegram_chat_id

      notification.update!(status: :skipped, error: 'no linked telegram connection')
      nil
    end
  end
end
