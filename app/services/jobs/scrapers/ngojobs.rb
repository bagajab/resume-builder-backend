# frozen_string_literal: true

module Jobs
  module Scrapers
    # Scrapes https://ngojobs.et/jobs.
    #
    # ngojobs is an Astro site, but its listing/detail shape matches the
    # Jobboardly pattern closely enough to reuse that base: /jobs?page=N listing
    # with a page=N+1 "Next" anchor, and a schema.org JobPosting JSON-LD on each
    # detail page. Two differences from the Jobboardly boards:
    #
    #   * Detail slugs are /jobs/<slug>-<id> (the id is a short alphanumeric, not
    #     8 hex chars).
    #   * The JSON-LD `url` IS the external apply link (e.g. a Google Form), so
    #     there's no separate on-page "Apply now" anchor.
    #
    # The address fields repeat the same "City, Ethiopia" string across
    # locality/region/street, so location/region are derived narrowly.
    class Ngojobs < Jobboardly
      BASE_URL = 'https://ngojobs.et'
      DETAIL_SLUG_RE = %r{/jobs/([a-z0-9][a-z0-9-]+-[a-z0-9]+)(?:[/?#]|\z)}

      def self.source
        'ngojobs'
      end

      private

      # ngojobs puts the real external apply target in the JSON-LD `url`.
      def apply_url(posting, _document)
        clean(posting['url'])
      end

      # locality/region/street all carry the same "City, Ethiopia" value; keep
      # the locality string as the location and its leading segment as region.
      def location_text(address)
        clean(address['addressLocality']) || clean(address['streetAddress'])
      end

      def build(slug, url, posting, document)
        attributes = super
        locality = clean(posting.dig('jobLocation', 'address', 'addressLocality'))
        attributes.merge(region: locality&.split(',')&.first&.strip.presence)
      end
    end
  end
end
