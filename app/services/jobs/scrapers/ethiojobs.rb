# frozen_string_literal: true

module Jobs
  module Scrapers
    # Scrapes https://ethiojobs.net/jobs.
    #
    # ethiojobs is a Next.js app; the listing data is server-embedded in the
    # __NEXT_DATA__ payload at props.pageProps.jobs.data, so we read structured
    # JSON rather than brittle DOM selectors.
    class Ethiojobs < Base
      BASE_URL = 'https://ethiojobs.net'
      LISTING_PATH = '/jobs'
      MAX_PAGES = 5
      REMOTE_LOCATION_TYPES = %w[remote hybrid].freeze

      def self.source
        'ethiojobs'
      end

      def scrape
        (1..MAX_PAGES).flat_map { |page| scrape_page(page) }.compact
      end

      private

      def scrape_page(page)
        document = fetch_document("#{BASE_URL}#{LISTING_PATH}?page=#{page}")
        entries = next_data(document).dig('props', 'pageProps', 'jobs', 'data')
        return [] if entries.blank?

        entries.filter_map { |entry| safe_parse(entry['slug']) { build(entry) } }
      end

      def build(entry)
        base_attributes(entry).merge(descriptive_attributes(entry))
      end

      def base_attributes(entry)
        slug = entry.fetch('slug')
        company = entry['company'] || {}
        catalogs = Array(entry['catalogs']).filter_map { |c| c['name'].presence }

        {
          source:,
          source_uid: slug,
          url: "#{BASE_URL}/jobs/#{slug}",
          apply_url: application_url(entry),
          title: squish(entry['title']),
          company_name: company['name'].presence,
          location: entry['state'].presence,
          region: entry['state'].presence,
          remote: REMOTE_LOCATION_TYPES.include?(entry['location_type'].to_s.downcase),
          category: catalogs.first,
          tags: catalogs
        }
      end

      def descriptive_attributes(entry)
        description = entry['description']

        {
          summary: truncate(strip_html(description)),
          description: description.presence,
          posted_on: parse_date(entry['date_published']),
          deadline_on: parse_date(entry['date_expiry']),
          metadata: metadata_for(entry)
        }
      end

      def metadata_for(entry)
        company = entry['company'] || {}

        {
          location_type: entry['location_type'].presence,
          type_code: entry['type'],
          level_code: entry['level'],
          application_method: entry['application_method'],
          application_email: entry['application_email'],
          company_slug: company['slug'],
          company_logo: company['logo']
        }.compact
      end

      def application_url(entry)
        return entry['career_page_link'] if entry['career_page_link'].present?

        email = entry['application_email']
        return "mailto:#{email}" if entry['application_method'].to_s.casecmp('email').zero? && email.present?

        nil
      end
    end
  end
end
