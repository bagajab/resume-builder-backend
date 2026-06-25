# frozen_string_literal: true

module Jobs
  module Scrapers
    # Scrapes https://palmjobs.et/jobs.
    #
    # palmjobs is a Next.js app whose SSR /jobs page only renders the ~20 newest
    # jobs (the rest load client-side via /api, which robots.txt disallows). The
    # full catalogue is enumerated from the flat sitemap instead: every
    # /jobs/<uuid> URL is a job detail page. Each detail page carries a rich
    # `job` object in __NEXT_DATA__.props.pageProps. Many postings are aggregated
    # from other boards (is_aggregated/source_url), so platform-native fields
    # (job_type, salary, logo, …) are frequently null and treated as optional.
    class Palmjobs < Base
      BASE_URL = 'https://palmjobs.et'
      SITEMAP_URL = 'https://palmjobs.et/sitemap.xml'
      DETAIL_PATH = '/jobs'
      # Detail slugs are UUIDs; category/location filter pages use word-slugs, so
      # the UUID shape cleanly isolates real job pages from the sitemap.
      JOB_UUID_RE = %r{/jobs/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})}
      REMOTE_TYPES = %w[remote hybrid].freeze

      def self.source
        'palmjobs'
      end

      def scrape
        job_uuids.filter_map do |uuid|
          url = detail_url(uuid)
          # Already enriched + fresh ⇒ skip the (paid) detail fetch.
          next refresh_marker(url) if skip_detail?(url)

          safe_parse(uuid) { scrape_detail(uuid, url) }
        end
      end

      private

      def job_uuids
        body = client.get(SITEMAP_URL)
        body.scan(JOB_UUID_RE).flatten.uniq
      end

      def scrape_detail(uuid, url)
        document = fetch_document(url)
        props = next_data(document).dig('props', 'pageProps')
        job = props&.dig('job')
        return if job.blank?

        build(uuid, url, props, job)
      end

      def build(uuid, url, props, job)
        base_attributes(uuid, url, props, job).merge(descriptive_attributes(job))
      end

      def base_attributes(uuid, url, props, job)
        {
          source:,
          source_uid: uuid,
          url:,
          apply_url: application_url(job),
          title: squish(job['job_title']),
          company_name: clean(props['companyName']) || clean(job['company_name']),
          company_logo_url: clean(props['logoUrl']) || clean(job['logo_url']),
          location: clean(job['job_location']),
          region: region_for(job['job_location']),
          remote: remote?(job),
          employment_type: normalize_employment_type(job['job_type']),
          experience_level: clean(job['experience_level']),
          education_level: clean(job['education_level']),
          category: clean(job['job_industry']),
          tags: tags_for(job)
        }
      end

      def descriptive_attributes(job)
        description = job['job_description']

        {
          summary: truncate(strip_html(description)),
          description: description.presence,
          salary: clean(job['salary_range']),
          salary_currency: clean(job['currency']),
          salary_min: integer_or_nil(job['min_salary']),
          salary_max: integer_or_nil(job['max_salary']),
          languages: string_array(job['required_languages']),
          posted_on: parse_date(job['date_posted']) || parse_date(job['created_at']),
          deadline_on: parse_date(job['application_deadline']),
          metadata: metadata_for(job)
        }
      end

      def tags_for(job)
        (string_array(job['skill_tags']) + string_array(job['required_skills'])).uniq
      end

      def application_url(job)
        return job['external_link'] if job['external_link'].present?

        email = job['email_application']
        email.present? ? "mailto:#{email}" : nil
      end

      def remote?(job)
        return true if REMOTE_TYPES.include?(job['remote_type'].to_s.downcase)

        job['job_location'].to_s.downcase.include?('remote')
      end

      # "Remote | Addis Ababa" / "Addis Ababa, Ethiopia" ⇒ the most specific part.
      def region_for(location)
        clean(location.to_s.split(/[|,]/).map(&:strip).reject { |part| part.casecmp('remote').zero? }.last)
      end

      def metadata_for(job)
        {
          is_aggregated: job['is_aggregated'],
          source_url: job['source_url'].presence,
          source_name: job['source_name'].presence,
          job_status: job['job_status'].presence,
          open_positions: job['open_positions'],
          benefits: string_array(job['benefits']).presence
        }.compact
      end

      def string_array(value)
        Array(value).filter_map { |item| clean(item) }
      end

      def integer_or_nil(value)
        Integer(value)
      rescue ArgumentError, TypeError
        nil
      end

      def detail_url(uuid)
        "#{BASE_URL}#{DETAIL_PATH}/#{uuid}"
      end
    end
  end
end
