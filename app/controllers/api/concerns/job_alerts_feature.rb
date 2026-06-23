# frozen_string_literal: true

module API
  module Concerns
    # Gates the Job Alerts endpoints behind the `job_alerts` Flipper flag. When the
    # flag is off for the current user the endpoints behave as if they don't exist.
    module JobAlertsFeature
      extend ActiveSupport::Concern

      included do
        before_action :ensure_job_alerts_enabled
      end

      private

      def ensure_job_alerts_enabled
        return if Flipper.enabled?(:job_alerts, current_user)

        skip_authorization
        skip_policy_scope
        render json: { errors: [{ message: I18n.t('api.errors.not_found') }] }, status: :not_found
      end
    end
  end
end
