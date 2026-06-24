# frozen_string_literal: true

module Jobs
  # Enriches a single Job with Gemini, off the scrape path. Enqueued by
  # Jobs::ScraperService for new jobs and for jobs whose source content changed.
  # Idempotent: Jobs::Enricher no-ops when the job is already up to date.
  class EnrichJob < ApplicationJob
    queue_as :low
    discard_on ActiveRecord::RecordNotFound

    def perform(job_id)
      job = Job.find_by(id: job_id)
      Jobs::Enricher.call(job) if job
    end
  end
end
