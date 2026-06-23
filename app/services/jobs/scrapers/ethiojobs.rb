# frozen_string_literal: true

module Jobs
  module Scrapers
    # Scrapes https://ethiojobs.net/jobs.
    #
    # ethiojobs is a Next.js app. Listing pages expose job slugs in
    # __NEXT_DATA__; each job's full description, requirements, and apply
    # instructions live on the detail page at /job/:slug.
    class Ethiojobs < Base
      BASE_URL = 'https://ethiojobs.net'
      LISTING_PATH = '/jobs'
      DETAIL_PATH = '/job'
      # Company logos come back as bucket-relative paths (e.g.
      # "company-logo/123/photo.jpg"); ethiojobs serves them from this R2 bucket.
      ASSET_BASE_URL = 'https://pub-f30882b481294faa997a4d11ff77ce65.r2.dev'
      MAX_PAGES = 5
      REMOTE_LOCATION_TYPES = %w[remote hybrid].freeze

      def self.source
        'ethiojobs'
      end

      def scrape
        (1..MAX_PAGES).flat_map { |page| scrape_listing_page(page) }.compact
      end

      private

      def scrape_listing_page(page)
        document = fetch_document("#{BASE_URL}#{LISTING_PATH}?page=#{page}")
        slugs = listing_slugs(document)
        return [] if slugs.empty?

        slugs.filter_map { |slug| safe_parse(slug) { scrape_detail(slug) } }
      end

      def listing_slugs(document)
        entries = next_data(document).dig('props', 'pageProps', 'jobs', 'data')
        return [] if entries.blank?

        entries.filter_map { |entry| entry['slug'].presence }
      end

      def scrape_detail(slug)
        document = fetch_document(detail_url(slug))
        entry = next_data(document).dig('props', 'pageProps', 'data')
        return if entry.blank?

        build(entry)
      end

      def detail_url(slug)
        "#{BASE_URL}#{DETAIL_PATH}/#{slug}"
      end

      def build(entry)
        base_attributes(entry).merge(descriptive_attributes(entry))
      end

      def base_attributes(entry)
        slug = entry.fetch('slug')
        company = entry['company'] || {}
        catalogs = catalog_names(entry)

        {
          source:,
          source_uid: slug,
          url: detail_url(slug),
          apply_url: application_url(entry),
          title: squish(entry['title']),
          company_name: company['name'].presence,
          company_logo_url: logo_url(company),
          location: location_text(entry),
          region: clean(entry['state']) || clean(entry['city']),
          remote: remote?(entry),
          employment_type: employment_type(entry),
          experience_level: experience_level(entry),
          category: catalogs.first,
          tags: catalogs
        }
      end

      def descriptive_attributes(entry)
        description = full_description(entry)

        {
          summary: truncate(strip_html(description)),
          description: description.presence,
          posted_on: parse_date(entry['date_published']),
          deadline_on: parse_date(entry['date_expiry']),
          metadata: metadata_for(entry)
        }
      end

      def full_description(entry)
        [
          entry['description'],
          entry['requirement'],
          entry['how_to_apply']
        ].filter_map(&:presence).join("\n\n").presence
      end

      def catalog_names(entry)
        Array(entry['catalog_names']).filter_map { |name| clean(name) }.presence ||
          Array(entry['catalogs']).filter_map do |catalog|
            catalog.is_a?(Hash) ? clean(catalog['name']) : clean(catalog)
          end
      end

      def location_text(entry)
        [entry['city'], entry['state'], entry['country']]
          .filter_map { |part| clean(part) }
          .uniq
          .join(', ')
          .presence
      end

      def remote?(entry)
        REMOTE_LOCATION_TYPES.include?(entry['location_type'].to_s.downcase)
      end

      def employment_type(entry)
        type_name = Array(entry['type_name']).compact.first
        normalize_employment_type(type_name) if type_name.present?
      end

      def experience_level(entry)
        from_work = Array(entry['work_experience_name']).compact.first
        return from_work if from_work.present?

        career_level_label(entry)
      end

      def career_level_label(entry)
        level = entry['career_level_name']
        return level['label'] if level.is_a?(Hash)

        clean(level)
      end

      def metadata_for(entry)
        company = entry['company'] || {}

        {
          location_type: entry['location_type'].presence,
          type_code: entry['type'],
          type_name: Array(entry['type_name']).presence,
          level_code: entry['level'],
          career_level: career_level_label(entry),
          application_method: entry['application_method'].presence,
          application_email: entry['application_email'].presence,
          company_slug: company['slug'],
          company_logo: logo_url(company),
          skills_mandatory: Array(entry['skills_mandatory_names']).presence,
          skills_desired: Array(entry['skills_desired_names']).presence,
          language_skills: Array(entry['language_skills_names']).presence,
          benefits: Array(entry['benefit_names']).presence,
          headcounts: entry['headcounts'],
          salary_currency: entry['salary_currency'].presence
        }.compact
      end

      # Logos may be absolute (legacy) or bucket-relative; normalise to an
      # absolute URL so the frontend can render them directly.
      def logo_url(company)
        absolute_url(company['logo'].presence, base: ASSET_BASE_URL)
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
