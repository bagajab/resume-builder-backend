# frozen_string_literal: true

module Jobs
  # Orchestrates the per-source scrapers and persists results into Job.
  #
  # The run is idempotent: jobs are upserted by their canonical URL, `last_seen_at`
  # is refreshed, and any previously-stored job from a source that is no longer
  # listed is marked inactive. A source that fails (or returns nothing) never
  # deactivates that source's existing jobs.
  class ScraperService
    SCRAPERS = [
      Scrapers::Ethiojobs,
      Scrapers::EthiopianReporter,
      Scrapers::HahuJobs
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
        next if attrs.blank? || attrs[:url].blank? || attrs[:title].blank?

        created += 1 if persist_record(attrs)
        seen_urls << attrs[:url]
      end

      [created, seen_urls]
    end

    # @return [Boolean] true when a new record was created
    def persist_record(attrs)
      now = Time.current
      job = Job.find_or_initialize_by(url: attrs[:url])
      created = job.new_record?
      job.first_seen_at ||= now
      job.assign_attributes(attrs.merge(active: true, last_seen_at: now))
      job.save!
      created
    rescue ActiveRecord::RecordInvalid => error
      logger.warn("[Jobs::ScraperService] skipped #{attrs[:url]}: #{error.message}")
      false
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
