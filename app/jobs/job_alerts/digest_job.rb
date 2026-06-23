# frozen_string_literal: true

module JobAlerts
  # Sends the daily/weekly digests. Scheduled via GoodJob cron with the frequency
  # passed as an argument (see config/initializers/good_job.rb).
  class DigestJob < ApplicationJob
    queue_as :default

    def perform(frequency)
      JobAlerts::DigestService.call(frequency:)
    end
  end
end
