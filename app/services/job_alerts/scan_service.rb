# frozen_string_literal: true

module JobAlerts
  # Scans live jobs against active alerts and records a JobAlertNotification for each
  # new match. Idempotent: the unique [job_alert_id, job_id] index means a job is
  # never notified twice for the same alert, even across overlapping runs. For
  # `instant` alerts a delivery job is enqueued immediately; digest alerts leave the
  # notification `pending` for JobAlerts::DigestService to pick up.
  class ScanService
    Result = Data.define(:alerts_scanned, :notifications_created)

    def self.call(...) = new(...).call

    def initialize(alerts: JobAlert.active.includes(:user), logger: Rails.logger)
      @alerts = alerts.to_a
      @logger = logger
    end

    def call
      created = @alerts.sum { |alert| scan_alert(alert) }
      Result.new(alerts_scanned: @alerts.size, notifications_created: created)
    end

    private

    attr_reader :logger

    def scan_alert(alert)
      run_at = Time.current
      created = 0
      candidates(alert).find_each do |job|
        result = Matcher.call(alert, job)
        created += 1 if result.matched? && record_match(alert, job, result)
      end
      alert.update!(last_run_at: run_at)
      created
    rescue StandardError => error
      logger.error("[JobAlerts::ScanService] alert ##{alert.id} failed: #{error.class} #{error.message}")
      created
    end

    # SQL pre-filter to keep the in-Ruby Matcher pass small. Hard filters that map
    # cleanly onto columns are applied here; the rest is left to the Matcher.
    def candidates(alert)
      scope = Job.live
      scope = scope.where(employment_type: alert.employment_types) if alert.employment_types.present?
      scope = scope.remote if alert.remote_preference == 'remote'
      scope = scope.where(remote: false) if alert.remote_preference == 'on_site'
      if alert.last_run_at
        scope = scope.where('jobs.first_seen_at >= :since OR jobs.created_at >= :since', since: alert.last_run_at)
      end
      scope
    end

    # @return [Boolean] true when a brand-new notification was created
    def record_match(alert, job, result)
      notification = JobAlertNotification.create!(
        job_alert: alert, job:, user_id: alert.user_id, match_score: result.score, status: :pending
      )
      DeliverNotificationJob.perform_later(notification.id) if alert.instant?
      true
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      false # already notified for this (alert, job) — the dedup guarantee
    end
  end
end
