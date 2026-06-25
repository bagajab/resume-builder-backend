# frozen_string_literal: true

module Jobs
  module Scrapers
    # Shared base for boards running on the "Jobboardly" SaaS platform
    # (etcareers.com, enjera.com). These are server-rendered (no __NEXT_DATA__):
    #
    #   * Listing pages live at /jobs?page=N (newest first) and expose job links
    #     of the form /jobs/<slug>-<8hex>. Pagination is driven by a "Next"
    #     anchor pointing at page=N+1; out-of-range pages silently clamp to
    #     page 1, so we walk sequentially and stop the moment the current page
    #     has no anchor targeting the *next* page number (clamp-safe).
    #   * Each detail page carries a schema.org JobPosting JSON-LD plus an
    #     on-page "Apply now" anchor — the real external apply target, which the
    #     JSON-LD omits.
    #
    # Subclasses set BASE_URL and .source.
    class Jobboardly < Base
      BASE_URL = nil
      # Safety cap on listing pagination; far above any board's real page count.
      MAX_PAGES = 80
      # /jobs/<slug>-<8hex> as either a relative or absolute href.
      DETAIL_SLUG_RE = %r{/jobs/([a-z0-9][a-z0-9-]*-[0-9a-f]{8})(?:[/?#]|\z)}

      def scrape
        listing_slugs.filter_map do |slug|
          url = detail_url(slug)
          # Already enriched + fresh ⇒ skip the (paid) detail fetch.
          next refresh_marker(url) if skip_detail?(url)

          safe_parse(slug) { scrape_detail(slug, url) }
        end
      end

      private

      def base_url
        self.class::BASE_URL or raise NotImplementedError, "#{self.class} must define BASE_URL"
      end

      # Walks /jobs?page=N until a page no longer links to the next page. The
      # MAX_PAGES range is just a safety cap; the real stop is an empty/duplicate
      # page (past the end, or the page-1 clamp) or the absence of a next link.
      def listing_slugs
        collected = []
        seen = Set.new

        (1..self.class::MAX_PAGES).each do |page|
          document = fetch_document("#{base_url}/jobs?page=#{page}")
          fresh = slugs_on(document).reject { |slug| seen.include?(slug) }
          break if fresh.empty?

          seen.merge(fresh)
          collected.concat(fresh)
          break unless next_page?(document, page)
        end

        collected
      end

      def slugs_on(document)
        document.css('a[href]').filter_map { |anchor|
          match = anchor['href'].to_s.match(self.class::DETAIL_SLUG_RE)
          match && match[1]
        }.uniq
      end

      # True when any anchor on the page targets ?page=<current+1>. Anchoring on
      # the specific next number (not just "a Next link exists") makes this
      # immune to the page-1 clamp, whose "Next" always points back to page=2.
      def next_page?(document, current_page)
        wanted = current_page + 1
        document.css('a[href]').any? do |anchor|
          anchor['href'].to_s.match?(/[?&]page=#{wanted}(?:\D|\z)/)
        end
      end

      def scrape_detail(slug, url)
        document = fetch_document(url)
        posting = job_posting_ld(document)
        return if posting.blank?

        build(slug, url, posting, document)
      end

      # Finds the JobPosting node among the page's JSON-LD blocks (a page may also
      # carry an EmploymentAgency block, or wrap nodes in an @graph).
      def job_posting_ld(document)
        document.css('script[type="application/ld+json"]').each do |node|
          parsed = safe_json(node.text)
          candidate = ld_candidates(parsed).find { |entry| entry['@type'] == 'JobPosting' }
          return candidate if candidate
        end
        nil
      end

      def ld_candidates(parsed)
        case parsed
        when Array then parsed
        when Hash then parsed['@graph'].is_a?(Array) ? parsed['@graph'] : [parsed]
        else []
        end
      end

      def safe_json(text)
        JSON.parse(text)
      rescue JSON::ParserError
        nil
      end

      def build(slug, url, posting, document)
        organization = posting['hiringOrganization'] || {}
        address = posting.dig('jobLocation', 'address') || {}

        {
          source:,
          source_uid: slug,
          url:,
          apply_url: apply_url(posting, document),
          title: squish(posting['title']),
          company_name: clean(organization['name']),
          company_logo_url: clean(organization['logo']),
          location: location_text(address),
          region: clean(address['addressRegion']) || clean(address['addressLocality']),
          remote: remote?(posting),
          employment_type: normalize_employment_type(Array(posting['employmentType']).first),
          description: posting['description'].presence,
          summary: truncate(strip_html(posting['description'])),
          posted_on: parse_date(posting['datePosted']),
          deadline_on: parse_date(posting['validThrough']),
          metadata: {
            country: clean(address['addressCountry']),
            jobboardly_id: posting.dig('identifier', 'value'),
            direct_apply: posting['directApply']
          }.compact
        }
      end

      def location_text(address)
        [address['addressLocality'], address['addressRegion'], address['addressCountry']]
          .filter_map { |part| clean(part) }
          .uniq
          .join(', ')
          .presence
      end

      def remote?(posting)
        return true if posting['jobLocationType'].to_s.casecmp('TELECOMMUTE').zero?

        "#{posting['title']} #{posting['description']}".downcase.include?('remote')
      end

      # The on-page "Apply now" anchor is the genuine external apply target
      # (mailto:, recruiter site, …). Jobboardly tags it id="apply-btn"; fall
      # back to the first anchor whose visible text begins with "Apply".
      # (Subclasses whose apply link lives in the JSON-LD override this.)
      def apply_url(_posting, document)
        anchor = document.at_css('a#apply-btn') ||
                 document.css('a[href]').find { |node| node.text.strip.downcase.start_with?('apply') }
        clean(anchor&.[]('href'))
      end

      def detail_url(slug)
        "#{base_url}/jobs/#{slug}"
      end
    end
  end
end
