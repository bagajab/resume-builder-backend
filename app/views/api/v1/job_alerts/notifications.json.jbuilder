# frozen_string_literal: true

json.alert do
  json.partial! 'api/v1/job_alerts/job_alert', job_alert: @job_alert
end

json.notifications @notifications do |notification|
  json.id notification.id
  json.status notification.status
  json.channel notification.channel
  json.match_score notification.match_score
  json.error notification.error
  json.sent_at notification.sent_at
  json.created_at notification.created_at
  json.job do
    json.partial! 'api/v1/jobs/job', job: notification.job
  end
end
