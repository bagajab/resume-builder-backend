# frozen_string_literal: true

module JobAlerts
  # Scans active alerts against live jobs. Enqueued right after ScrapeJobsJob and on
  # an hourly cron safety net (see config/initializers/good_job.rb). Idempotent.
  class ScanJob < ApplicationJob
    queue_as :default

    def perform
      JobAlerts::ScanService.call
    end
  end
end
