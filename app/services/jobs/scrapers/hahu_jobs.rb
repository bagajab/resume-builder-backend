# frozen_string_literal: true

module Jobs
  module Scrapers
    # Scrapes https://www.hahu.jobs.
    #
    # hahu is a Nuxt SPA backed by a public (anonymous-readable) Hasura GraphQL
    # API, so we query it directly instead of rendering the client app.
    class HahuJobs < Base
      GRAPHQL_ENDPOINT = 'https://graph.aggregator.hahu.jobs/v1/graphql'
      DETAIL_URL = 'https://www.hahu.jobs/jobs'
      ORIGIN = 'https://www.hahu.jobs'
      PAGE_SIZE = 20
      MAX_PAGES = 3

      QUERY = <<~GRAPHQL
        query Jobs($limit: Int!, $offset: Int!) {
          jobs(
            limit: $limit
            offset: $offset
            order_by: { posted_on: desc_nulls_last }
            where: { expired: { _eq: false } }
          ) {
            id
            title
            summary
            description
            location
            salary
            salary_currency
            deadline
            posted_on
            type
            application_url
            application_email
            how_to_apply
            is_online
            years_of_experience
            company { name }
            area { name }
            position { name }
            minimum_education_level { name }
          }
        }
      GRAPHQL

      def self.source
        'hahu_jobs'
      end

      def scrape
        results = []

        MAX_PAGES.times do |page|
          batch = fetch_page(offset: page * PAGE_SIZE)
          break if batch.blank?

          results.concat(batch.filter_map { |entry| safe_parse(entry['id']) { build(entry) } })
          break if batch.size < PAGE_SIZE
        end

        results
      end

      private

      def fetch_page(offset:)
        payload = { query: QUERY, variables: { limit: PAGE_SIZE, offset: } }
        body = client.post_json(GRAPHQL_ENDPOINT, payload, headers: { 'Origin' => ORIGIN })

        if body['errors'].present?
          logger.warn("[#{self.class.name}] GraphQL errors: #{body['errors']}")
          return []
        end

        body.dig('data', 'jobs') || []
      end

      def build(entry)
        base_attributes(entry).merge(descriptive_attributes(entry))
      end

      def base_attributes(entry)
        id = entry.fetch('id')

        {
          source:,
          source_uid: id,
          url: "#{DETAIL_URL}/#{id}",
          apply_url: application_url(entry),
          title: clean(entry['title']),
          company_name: clean(entry.dig('company', 'name')),
          location: clean(entry['location']) || clean(entry.dig('area', 'name')),
          region: clean(entry.dig('area', 'name')),
          remote: entry['is_online'] == true,
          employment_type: normalize_employment_type(entry['type']),
          category: clean(entry.dig('position', 'name'))
        }
      end

      def descriptive_attributes(entry)
        description = entry['description']

        {
          education_level: clean(entry.dig('minimum_education_level', 'name')),
          experience_level: experience_level(entry['years_of_experience']),
          salary: salary(entry),
          summary: truncate(clean(entry['summary'])),
          description: description.presence,
          posted_on: parse_date(entry['posted_on']),
          deadline_on: parse_date(entry['deadline']),
          metadata: {
            type: entry['type'],
            years_of_experience: entry['years_of_experience'],
            is_online: entry['is_online'],
            how_to_apply: squish(entry['how_to_apply'])
          }.compact
        }
      end

      def application_url(entry)
        return entry['application_url'] if entry['application_url'].present?

        email = entry['application_email']
        email.present? ? "mailto:#{email}" : nil
      end

      def experience_level(years)
        return if years.blank? || years.to_i.zero?

        "#{years.to_i}+ years"
      end

      def salary(entry)
        amount = entry['salary']
        return if amount.blank? || amount.to_f.zero?

        [amount, entry['salary_currency']].compact.join(' ').strip.presence
      end
    end
  end
end
