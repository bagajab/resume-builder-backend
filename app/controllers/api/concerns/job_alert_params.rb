# frozen_string_literal: true

module API
  module Concerns
    # The permitted JobAlert attributes, shared by the REST controller and the
    # Telegram Mini App controller so both go through the exact same allow-list.
    module JobAlertParams
      private

      def job_alert_params
        params.expect(
          job_alert: [:name, :remote_preference, :frequency, :salary_min, :salary_max, :salary_currency,
                      { titles: [], keywords: [], locations: [], experience_levels: [], employment_types: [] }]
        )
      end
    end
  end
end
