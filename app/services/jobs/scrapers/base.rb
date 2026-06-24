# frozen_string_literal: true

require 'nokogiri'

module Jobs
  module Scrapers
    # Base class for source scrapers. Each subclass implements `#scrape` and
    # returns an array of attribute hashes ready to be upserted into Job.
    #
    # Subclasses must define `self.source` (one of Job::SOURCES).
    class Base
      EMPLOYMENT_TYPE_ALIASES = {
        'full time' => 'full_time',
        'full-time' => 'full_time',
        'fulltime' => 'full_time',
        'part time' => 'part_time',
        'part-time' => 'part_time',
        'contract' => 'contract',
        'contractual' => 'contract',
        'temporary' => 'temporary',
        'temp' => 'temporary',
        'internship' => 'internship',
        'intern' => 'internship',
        'freelance' => 'freelance',
        'volunteer' => 'volunteer',
        'voluntary' => 'volunteer'
      }.freeze

      NULLISH = %w[null nil n/a na none undefined -].freeze
      def self.source
        raise NotImplementedError, "#{name} must define .source"
      end

      def initialize(client: Jobs::HttpClient.new, logger: Rails.logger)
        @client = client
        @logger = logger
      end

      # @return [Array<Hash>] attribute hashes for Job upsert
      def scrape
        raise NotImplementedError, "#{self.class.name} must implement #scrape"
      end

      protected

      attr_reader :client, :logger

      def source
        self.class.source
      end

      def fetch_document(url, headers: {})
        Nokogiri::HTML(client.get(url, headers:))
      end

      # True when we already hold a fresh, complete enrichment for this URL, so the
      # (paid) detail fetch + Gemini call can be skipped. Scrapers that gate detail
      # fetches on this should emit `refresh_marker(url)` for skipped jobs so the
      # job is still counted as seen this run (and not deactivated).
      def skip_detail?(url)
        Jobs::Enricher.fresh?(url)
      end

      def refresh_marker(url)
        { source:, url:, refresh_only: true }
      end

      # Extracts and parses the Next.js __NEXT_DATA__ payload from a document.
      def next_data(document)
        node = document.at_css('script#__NEXT_DATA__')
        return {} if node.nil?

        JSON.parse(node.text)
      rescue JSON::ParserError => error
        logger.warn("[#{self.class.name}] could not parse __NEXT_DATA__: #{error.message}")
        {}
      end

      def normalize_employment_type(value)
        key = value.to_s.strip.downcase
        return if key.blank?

        mapped = EMPLOYMENT_TYPE_ALIASES[key] || key.tr(' -', '__')
        Job::EMPLOYMENT_TYPES.include?(mapped) ? mapped : nil
      end

      def strip_html(html)
        return if html.blank?

        text = Nokogiri::HTML.fragment(html.to_s).text
        squish(text)
      end

      def squish(text)
        text.to_s.gsub(/\s+/, ' ').strip.presence
      end

      # Normalises a value to nil when it is blank or a literal placeholder such
      # as the string "null" (which some APIs return for missing fields).
      def clean(value)
        text = squish(value)
        return if text.nil? || NULLISH.include?(text.downcase)

        text
      end

      def truncate(text, length: 320)
        return if text.blank?

        text.length > length ? "#{text[0, length].rstrip}…" : text
      end

      def parse_date(value)
        return if value.blank?

        Date.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def absolute_url(href, base:)
        return if href.blank?

        URI.join(base, href).to_s
      rescue URI::Error
        href
      end

      # Wraps per-item parsing so a single malformed entry never aborts a run.
      def safe_parse(identifier)
        yield
      rescue StandardError => error
        logger.warn("[#{self.class.name}] skipped #{identifier}: #{error.class} #{error.message}")
        nil
      end
    end
  end
end
