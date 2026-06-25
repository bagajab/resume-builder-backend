# frozen_string_literal: true

module Jobs
  module Scrapers
    # Scrapes https://guzojobs.com/jobs.
    #
    # guzojobs is WordPress running the NooThemes "JobMonster" theme. Detail
    # pages carry no JobPosting JSON-LD, so we read two sources:
    #
    #   * Listing pages /jobs/page/N/ — `article.noo_job` cards expose company,
    #     posted/closing dates, and category/type/location encoded in the
    #     article's class list (the WP REST API omits company + the closing
    #     date, so the HTML cards are required). The listing 404s past the last
    #     page, which is our end-of-pagination signal.
    #   * WP REST GET /wp-json/wp/v2/noo_job/<id> — the full description
    #     (content.rendered), fetched per job.
    class Guzojobs < Base
      BASE_URL = 'https://guzojobs.com'
      LISTING_PATH = '/jobs/page'
      REST_DETAIL_PATH = '/wp-json/wp/v2/noo_job'
      MAX_PAGES = 60
      # Cards render the closing date as " - July 10, 2026"; pull the date out.
      DATE_RE = /([A-Z][a-z]+\s+\d{1,2},\s*\d{4})/

      def self.source
        'guzojobs'
      end

      def scrape
        listing_cards.filter_map do |card|
          url = card[:url]
          next if url.blank?
          # Already enriched + fresh ⇒ skip the (paid) REST description fetch.
          next refresh_marker(url) if skip_detail?(url)

          safe_parse(card[:source_uid]) { build(card) }
        end
      end

      private

      # Walks /jobs/page/N/ collecting one hash per card until the listing 404s
      # or returns no cards.
      def listing_cards
        cards = []

        (1..MAX_PAGES).each do |page|
          document = fetch_listing_page(page)
          break if document.nil?

          articles = document.css('article.noo_job')
          break if articles.empty?

          articles.each do |article|
            card = safe_parse("page #{page} card") { parse_card(article) }
            cards << card if card
          end
        end

        cards
      end

      def fetch_listing_page(page)
        fetch_document(listing_url(page))
      rescue Jobs::HttpClient::Error => error
        # A 404 past the final page is the normal end-of-pagination signal.
        logger.info("[#{self.class.name}] listing ended at page #{page}: #{error.message}")
        nil
      end

      # Page 1 is the bare /jobs/ index — /jobs/page/1/ 301-redirects to it, and
      # our HTTP client doesn't follow redirects. Pages 2+ use /jobs/page/N/.
      def listing_url(page)
        page <= 1 ? "#{BASE_URL}/jobs/" : "#{BASE_URL}#{LISTING_PATH}/#{page}/"
      end

      def parse_card(article)
        classes = article['class'].to_s.split
        id = taxonomy(classes, 'post')
        return if id.blank?

        {
          source_uid: id,
          url: card_url(article),
          title: squish(article.at_css('h3.loop-item-title a')&.text),
          company_name: squish(article.at_css('span.job-company a span')&.text),
          employment_type: employment_type(article, classes),
          location: card_location(article, classes),
          category: humanize(taxonomy(classes, 'job_category')),
          posted_on: card_posted_on(article),
          deadline_on: card_deadline_on(article)
        }
      end

      def card_url(article)
        href = article['data-url'].presence || article.at_css('h3.loop-item-title a')&.[]('href')
        absolute_url(href, base: BASE_URL)
      end

      def employment_type(article, classes)
        label = squish(article.at_css('span.job-type a span')&.text) || humanize(taxonomy(classes, 'job_type'))
        normalize_employment_type(label)
      end

      def card_location(article, classes)
        squish(article.at_css('span.job-location a em')&.text) || humanize(taxonomy(classes, 'job_location'))
      end

      def card_posted_on(article)
        iso = article.at_css('time.entry-date')&.[]('datetime')
        parse_date(iso) || parse_date(extract_date(article.at_css('span.job-date__posted')&.text))
      end

      def card_deadline_on(article)
        parse_date(extract_date(article.at_css('span.job-date__closing')&.text))
      end

      def extract_date(text)
        match = text.to_s.match(DATE_RE)
        match && match[1]
      end

      # Reads a `<prefix>-<slug>` token out of the article's class list.
      def taxonomy(classes, prefix)
        token = classes.find { |klass| klass.start_with?("#{prefix}-") }
        token&.delete_prefix("#{prefix}-").presence
      end

      def humanize(slug)
        return if slug.blank?

        slug.tr('-', ' ').split.map(&:capitalize).join(' ')
      end

      def build(card)
        detail = fetch_detail(card[:source_uid])
        description = detail&.dig('content', 'rendered')

        {
          source:,
          source_uid: card[:source_uid],
          url: card[:url],
          title: card[:title].presence || squish(strip_html(detail&.dig('title', 'rendered'))),
          company_name: card[:company_name],
          location: card[:location],
          remote: card[:location].to_s.downcase.include?('remote'),
          employment_type: card[:employment_type],
          category: card[:category],
          tags: Array(card[:category]).compact,
          description: description.presence,
          summary: truncate(strip_html(description)) || truncate(card[:title]),
          posted_on: card[:posted_on] || parse_date(detail&.dig('date')),
          deadline_on: card[:deadline_on],
          metadata: { wp_id: card[:source_uid].to_i }
        }
      end

      def fetch_detail(id)
        body = client.get("#{BASE_URL}#{REST_DETAIL_PATH}/#{id}?_fields=id,date,title,content")
        JSON.parse(body)
      rescue Jobs::HttpClient::Error, JSON::ParserError => error
        logger.warn("[#{self.class.name}] detail #{id} failed: #{error.message}")
        nil
      end
    end
  end
end
