# frozen_string_literal: true

module Jobs
  module Scrapers
    # Scrapes https://etcareers.com/jobs (a Jobboardly board, ~10 jobs/page).
    # All field extraction lives in Jobboardly; this only pins the host + source.
    class Etcareers < Jobboardly
      BASE_URL = 'https://etcareers.com'

      def self.source
        'etcareers'
      end
    end
  end
end
