# frozen_string_literal: true

module Jobs
  # Orchestrates the per-source scrapers and persists results into Job.
  #
  # The run is idempotent: jobs are upserted by their canonical URL, `last_seen_at`
  # is refreshed, and any previously-stored job from a source that is no longer
  # listed is marked inactive. A source that fails (or returns nothing) never
  # deactivates that source's existing jobs.
  class ScraperService
    # Ethiojobs only for now. EthiopianReporter and HahuJobs are temporarily
    # disabled — re-add them here to bring them back.
    SCRAPERS = [
      Scrapers::Ethiojobs
      # Scrapers::EthiopianReporter,
      # Scrapers::HahuJobs
    ].freeze

    Result = Data.define(:source, :upserted, :created, :deactivated, :error) do
      def ok? = error.nil?
    end

    def self.call(...)
      new(...).call
    end

    def initialize(logger: Rails.logger)
      @logger = logger
    end

    # @return [Array<Result>] one summary per source
    def call
      # Every scraped job is enriched with Gemini; without a key there's no point
      # paying the scrape cost, so skip the run entirely.
      unless Jobs::Enricher.enabled?
        logger.warn('[Jobs::ScraperService] skipped: Gemini enrichment is not configured (GEMINI_API_KEY)')
        return []
      end

      SCRAPERS.map { |scraper_class| run_scraper(scraper_class) }.tap { |results| log_summary(results) }
    end

    private

    attr_reader :logger

    def run_scraper(scraper_class)
      source = scraper_class.source
      records = scraper_class.new(logger:).scrape
      created, seen_urls = import(records)
      deactivated = deactivate_missing(source, seen_urls)
      Result.new(source:, upserted: seen_urls.size, created:, deactivated:, error: nil)
    rescue StandardError => error
      logger.error("[Jobs::ScraperService] #{source} failed: #{error.class} #{error.message}")
      Result.new(source:, upserted: 0, created: 0, deactivated: 0, error: error.message)
    end

    # @return [Array(Integer, Array<String>)] count of new records and the URLs seen
    def import(records)
      created = 0
      seen_urls = []

      Array(records).each do |attrs|
        next if attrs.blank? || attrs[:url].blank?

        outcome = ingest(attrs)
        next if outcome == :skip

        created += 1 if outcome == :created
        seen_urls << attrs[:url]
      end

      [created, seen_urls]
    end

    # @return [Symbol] :created / :updated / :refreshed, or :skip when ignored
    def ingest(attrs)
      # A scraper that skipped a detail fetch (already enriched + fresh) emits a
      # refresh-only marker: keep the job alive and seen, but don't re-process it.
      if attrs[:refresh_only]
        refresh_seen(attrs[:url])
        return :refreshed
      end
      return :skip if attrs[:title].blank?

      persist_record(attrs) ? :created : :updated
    end

    # @return [Boolean] true when a new record was created
    def persist_record(attrs)
      now = Time.current
      job = Job.find_or_initialize_by(url: attrs[:url])
      created = job.new_record?
      hash = Jobs::Enricher.content_hash(attrs)
      content_changed = job.content_hash != hash
      job.first_seen_at ||= now
      job.assign_attributes(attrs.merge(active: true, last_seen_at: now, content_hash: hash))
      # A changed source invalidates a prior enrichment; flag it for a refresh so
      # the `unless enriched?` guard below re-enqueues it.
      job.enrichment_status = 'pending' if content_changed && job.enrichment_status == 'enriched'
      job.save!
      enqueue_enrichment(job) unless job.enriched?
      created
    rescue ActiveRecord::RecordInvalid => error
      logger.warn("[Jobs::ScraperService] skipped #{attrs[:url]}: #{error.message}")
      false
    end

    # Refreshes lifecycle bookkeeping for a job we deliberately didn't re-fetch.
    def refresh_seen(url)
      Job.where(url:)
         # Touch-only; the record is unchanged so validations add nothing.
         .update_all(active: true, last_seen_at: Time.current, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end

    def enqueue_enrichment(job)
      return unless Jobs::Enricher.enabled?

      Jobs::EnrichJob.perform_later(job.id)
    end

    def deactivate_missing(source, seen_urls)
      return 0 if seen_urls.empty?

      Job.from_source(source)
         .where(active: true)
         .where.not(url: seen_urls)
         # Bulk lifecycle flip; per-record validations are intentionally skipped.
         .update_all(active: false, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end

    def log_summary(results)
      results.each do |result|
        if result.ok?
          logger.info(
            "[Jobs::ScraperService] #{result.source}: #{result.upserted} listed " \
            "(#{result.created} new), #{result.deactivated} deactivated"
          )
        else
          logger.error("[Jobs::ScraperService] #{result.source}: ERROR #{result.error}")
        end
      end
    end
  end
end
