# frozen_string_literal: true

json.job_alerts @job_alerts do |job_alert|
  json.partial! 'api/v1/job_alerts/job_alert', job_alert:
end
