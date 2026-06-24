# frozen_string_literal: true

require 'digest'

module Jobs
  # AI enrichment layer for a single Job. Turns the scraped, source-shaped fields
  # into a normalized, alert-ready profile (Gemini via Jobs::Ai::GeminiClient) and
  # writes the results into the `ai_*`/structured columns, leaving the original
  # scraped columns untouched.
  #
  # Cost discipline:
  #   * Content is boilerplate-stripped and size-capped before it is sent.
  #   * A content hash is stored on the Job; an unchanged hash (for the current
  #     enrichment_version) short-circuits before any model call.
  #   * A shared result cache keyed by that hash means the same posting cross-listed
  #     on two boards is only enriched once.
  #   * `fresh?` lets the scrapers skip the detail fetch entirely for jobs that are
  #     already enriched and recent.
  class Enricher
    # Bump when the prompt/schema/normalization changes so jobs are re-enriched.
    ENRICHMENT_VERSION = 1
    # How long an enrichment is trusted before the scrapers re-fetch the detail
    # page to check for source changes.
    FRESH_FOR = 7.days
    # Generous enough that a long posting's cleaned description + skill/duty arrays
    # fit without truncating the JSON (a truncated response fails to parse). Billed
    # on actual output, so short postings stay cheap.
    MAX_OUTPUT_TOKENS = 8_192
    # ~ a few thousand tokens; guards a runaway description without losing the meat.
    MAX_CONTENT_CHARS = 12_000
    RESULT_CACHE_NAMESPACE = 'jobs/enrich'
    RESULT_CACHE_TTL = 7.days

    # Source fields a content hash / the model prompt are built from.
    SOURCE_FIELDS = %i[
      title company_name location employment_type experience_level
      education_level salary summary description category
    ].freeze

    def self.call(...) = new(...).call

    def self.enabled?
      Ai::GeminiClient.configured?
    end

    # True when this URL already has a recent, complete enrichment — the scrapers
    # use it to skip the paid detail fetch + enrichment entirely.
    def self.fresh?(url)
      Job.where(url:)
         .where(enrichment_status: 'enriched', enrichment_version: ENRICHMENT_VERSION)
         .exists?(enriched_at: FRESH_FOR.ago..)
    end

    # Stable digest of the source content. ScraperService stores it on the Job so a
    # later scrape can detect when the source changed and trigger re-enrichment.
    # Accepts either a Job or an attributes hash.
    def self.content_hash(fields)
      Digest::SHA256.hexdigest(source_text(fields))
    end

    # Boilerplate-stripped, size-capped text sent to the model. Built from the
    # structured fields we already hold, so no page is re-fetched.
    def self.source_text(fields)
      values = SOURCE_FIELDS.map { |key| field(fields, key) }
      values << metadata_text(field(fields, :metadata))
      values.filter_map { |value| strip(value).presence }.join("\n").first(MAX_CONTENT_CHARS)
    end

    def self.field(fields, key)
      fields.respond_to?(:public_send) && !fields.is_a?(Hash) ? fields.public_send(key) : fields[key]
    end
    private_class_method :field

    def self.strip(value)
      ActionController::Base.helpers.strip_tags(value.to_s).gsub(/\s+/, ' ').strip
    end
    private_class_method :strip

    def self.metadata_text(metadata)
      return '' if metadata.blank?

      metadata.to_h.values.flatten.filter_map { |value| value.to_s.strip.presence }.join(' ')
    end
    private_class_method :metadata_text

    def initialize(job, client: nil, logger: Rails.logger)
      @job = job
      @client = client || Ai::GeminiClient.new(logger:)
      @logger = logger
    end

    # @return [Job] the (possibly) updated job
    def call
      return job unless self.class.enabled?

      hash = self.class.content_hash(job)
      return job if up_to_date?(hash)

      apply!(cached_generate(hash), hash)
      job
    rescue Ai::GeminiClient::Error => e
      logger.warn("[Jobs::Enricher] job ##{job.id} failed: #{e.message}")
      mark_failed!
      job
    end

    private

    attr_reader :job, :client, :logger

    def up_to_date?(hash)
      job.enriched? && job.content_hash == hash && job.enrichment_version == ENRICHMENT_VERSION
    end

    # Cache the normalized result by content hash so an identical posting on another
    # board reuses it instead of paying for a second model call.
    def cached_generate(hash)
      key = "#{RESULT_CACHE_NAMESPACE}/#{ENRICHMENT_VERSION}/#{Ai::GeminiClient::MODEL}/#{hash}"
      Rails.cache.fetch(key, expires_in: RESULT_CACHE_TTL) do
        raw = client.generate_json(
          system: Ai::Prompt::SYSTEM,
          user: Ai::Prompt.user(self.class.source_text(job), category_hint: job.category),
          max_output_tokens: MAX_OUTPUT_TOKENS
        )
        Normalizer.call(raw)
      end
    end

    def apply!(attrs, hash)
      attrs = attrs.merge(
        content_hash: hash,
        enriched_at: Time.current,
        enrichment_model: Ai::GeminiClient::MODEL,
        enrichment_version: ENRICHMENT_VERSION,
        enrichment_status: 'enriched'
      )
      # Keep the boolean `remote` consistent with the normalized remote_type.
      attrs[:remote] = %w[remote hybrid].include?(attrs[:remote_type]) if attrs[:remote_type]
      job.update!(attrs)
    end

    def mark_failed!
      # update_column avoids re-validating an otherwise-fine record on a model blip.
      job.update_column(:enrichment_status, 'failed') if job.persisted? # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
