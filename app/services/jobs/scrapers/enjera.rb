# frozen_string_literal: true

module Jobs
  module Scrapers
    # Scrapes https://enjera.com/jobs (a Jobboardly board, ~50 jobs/page; its
    # detail JSON-LD often carries only addressCountry — handled generically in
    # Jobboardly). Host + source only; extraction lives in the base class.
    class Enjera < Jobboardly
      BASE_URL = 'https://enjera.com'

      def self.source
        'enjera'
      end
    end
  end
end
