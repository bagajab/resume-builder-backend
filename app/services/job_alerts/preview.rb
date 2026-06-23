# frozen_string_literal: true

module JobAlerts
  # Returns a sample of jobs that an (unsaved) alert would currently match, ordered
  # by match score. Powers the "preview matches" affordance in the alert editor.
  # Bounded so an ad-hoc preview never scans the whole table.
  class Preview
    SCAN_LIMIT = 500
    RESULT_LIMIT = 20

    def self.call(...) = new(...).call

    def initialize(alert, limit: RESULT_LIMIT)
      @alert = alert
      @limit = limit
    end

    def call
      Job.live.recent.limit(SCAN_LIMIT)
         .map { |job| [job, Matcher.call(@alert, job)] }
         .select { |_job, result| result.matched? }
         .sort_by { |_job, result| -result.score }
         .first(@limit)
         .map(&:first)
    end
  end
end
