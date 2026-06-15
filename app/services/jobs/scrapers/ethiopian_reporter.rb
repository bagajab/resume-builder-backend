# frozen_string_literal: true

module Jobs
  module Scrapers
    # Scrapes https://www.ethiopianreporterjobs.com/jobs-in-ethiopia/.
    #
    # The site runs the "Noo Jobmonster" WordPress theme, which renders each
    # listing as a `.loop-item-wrap` card with predictable child classes.
    class EthiopianReporter < Base
      BASE_URL = 'https://www.ethiopianreporterjobs.com'
      LISTING_PATH = '/jobs-in-ethiopia'
      MAX_PAGES = 3

      def self.source
        'ethiopian_reporter'
      end

      def scrape
        (1..MAX_PAGES).flat_map { |page| scrape_page(page) }.compact
      end

      private

      def scrape_page(page)
        document = fetch_document(page_url(page))
        cards = document.css('.loop-item-wrap')
        return [] if cards.empty?

        cards.filter_map.with_index do |card, index|
          safe_parse("page #{page} item #{index}") { build(card) }
        end
      end

      def page_url(page)
        return "#{BASE_URL}#{LISTING_PATH}/" if page <= 1

        "#{BASE_URL}#{LISTING_PATH}/page/#{page}/"
      end

      def build(card)
        link = card.at_css('a.job-details-link') || card.at_css('.loop-item-title a')
        url = absolute_url(link&.[]('href'), base: BASE_URL)
        title = text_at(card, '.loop-item-title')
        return if url.blank? || title.blank?

        base_attributes(card, url, title).merge(date_attributes(card))
      end

      def base_attributes(card, url, title)
        type_text = text_at(card, '.job-type')

        {
          source:,
          source_uid: url[%r{/(\d+)/?\z}, 1],
          url:,
          apply_url: url,
          title:,
          company_name: text_at(card, '.job-company'),
          location: text_at(card, '.job-location'),
          region: text_at(card, '.job-location'),
          employment_type: normalize_employment_type(type_text),
          experience_level: text_at(card, '.job-experience_level'),
          summary: truncate(text_at(card, '.loop-item-content')),
          metadata: { employment_type_raw: type_text }.compact
        }
      end

      def date_attributes(card)
        {
          posted_on: parse_loose_date(raw_text(card, '.job-date__posted')),
          deadline_on: parse_loose_date(raw_text(card, '.job-date__closing'))
        }
      end

      def text_at(card, selector)
        squish(card.at_css(selector)&.text)
      end

      def raw_text(card, selector)
        card.at_css(selector)&.text
      end

      # Listing dates may arrive as "Posted: Jun 14, 2026" or a bare date, so
      # strip any leading label before parsing.
      def parse_loose_date(text)
        cleaned = squish(text)&.sub(/\A[^:]*:\s*/, '')
        parse_date(cleaned)
      end
    end
  end
end
