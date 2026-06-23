# frozen_string_literal: true

module JobAlerts
  # Bundles each user's pending Telegram notifications for a given frequency into a
  # single digest message. Notifications without a linked Telegram are marked
  # `skipped`; delivery failures are marked `failed` (with the error) so nothing is
  # silently lost and a re-run won't double-send already-`sent` rows.
  class DigestService
    def self.call(...) = new(...).call

    def initialize(frequency:, client: Telegram::Client.new, logger: Rails.logger)
      @frequency = frequency.to_s
      @client = client
      @logger = logger
    end

    def call
      pending_by_user.sum { |user_id, notifications| deliver(user_id, notifications) ? 1 : 0 }
    end

    private

    attr_reader :frequency, :client, :logger

    def pending_by_user
      JobAlertNotification
        .pending
        .joins(:job_alert)
        .where(job_alerts: { frequency: JobAlert.frequencies.fetch(frequency) })
        .includes(:job)
        .group_by(&:user_id)
    end

    def deliver(user_id, notifications)
      connection = TelegramConnection.linked.find_by(user_id:)
      if connection&.telegram_chat_id.blank?
        return mark(notifications, :skipped,
                    'no linked telegram connection') && false
      end

      text = TelegramMessage.digest(notifications.map(&:job), frequency:)
      client.send_message(chat_id: connection.telegram_chat_id, text:)
      mark(notifications, :sent)
      true
    rescue Telegram::Client::Error => error
      logger.error("[JobAlerts::DigestService] user ##{user_id}: #{error.message}")
      mark(notifications, :failed, error.message)
      false
    end

    def mark(notifications, status, error = nil)
      now = Time.current
      attrs = { status: JobAlertNotification.statuses.fetch(status.to_s), error:, updated_at: now }
      attrs[:sent_at] = now if status == :sent
      # Bulk status flip; per-record validations are intentionally skipped.
      JobAlertNotification.where(id: notifications.map(&:id)).update_all(attrs) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
