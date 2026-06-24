# frozen_string_literal: true

module API
  module V1
    class JobAlertsController < API::V1::APIController
      include API::Concerns::JobAlertsFeature
      include API::Concerns::JobAlertParams

      before_action :set_job_alert, only: %i[update destroy pause resume notifications]

      def index
        @job_alerts = policy_scope(JobAlert).includes(:job_alert_notifications).order(created_at: :desc)
      end

      def create
        @job_alert = current_user.job_alerts.new(job_alert_params)
        authorize @job_alert
        @job_alert.save!
        render :show, status: :created
      end

      def update
        @job_alert.update!(job_alert_params)
        render :show
      end

      def destroy
        @job_alert.destroy!
        head :no_content
      end

      def pause
        @job_alert.paused!
        render :show
      end

      def resume
        @job_alert.active!
        render :show
      end

      # Alert history: which jobs matched and their delivery status.
      def notifications
        @notifications = @job_alert.job_alert_notifications
                                   .includes(:job).order(created_at: :desc).limit(100)
      end

      # Live preview of jobs the (unsaved) criteria would match.
      def preview
        authorize JobAlert, :preview?
        alert = current_user.job_alerts.new(job_alert_params)
        @jobs = JobAlerts::Preview.call(alert)
      end

      private

      def set_job_alert
        @job_alert = policy_scope(JobAlert).find(params.expect(:id))
        authorize @job_alert
      end
    end
  end
end
