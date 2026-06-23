# frozen_string_literal: true

# Aggregates job postings from the supported Ethiopian job boards into the Job
# table. Scheduled daily via GoodJob cron (see config/initializers/good_job.rb)
# and safe to run ad hoc — the underlying service is idempotent.
class ScrapeJobsJob < ApplicationJob
  queue_as :low

  def perform
    Jobs::ScraperService.call
    # Fan out to alert matching as soon as fresh jobs land.
    JobAlerts::ScanJob.perform_later
  end
end
