# frozen_string_literal: true

Rails.application.configure do
  # Don't depend on transactions
  config.good_job.enqueue_after_transaction_commit = true
  # Prioritize the queue high over the rest
  config.good_job.queues = 'high,*'

  # Run scheduled jobs (cron) in production by default. Toggle locally with
  # GOOD_JOB_ENABLE_CRON=true when you want to exercise the schedule.
  config.good_job.enable_cron =
    ActiveModel::Type::Boolean.new.cast(ENV.fetch('GOOD_JOB_ENABLE_CRON', Rails.env.production?))
  config.good_job.cron_graceful_restart_period = 5.minutes

  config.good_job.cron = {
    scrape_jobs: {
      # Daily at 02:00 (server time). Override with SCRAPE_JOBS_CRON.
      cron: ENV.fetch('SCRAPE_JOBS_CRON', '0 2 * * *'),
      class: 'ScrapeJobsJob',
      description: 'Aggregate job postings from Ethiopian job boards daily'
    }
  }
end
