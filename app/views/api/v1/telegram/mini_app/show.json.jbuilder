# frozen_string_literal: true

json.alert do
  json.partial! 'api/v1/job_alerts/job_alert', job_alert: @job_alert
end

# Why this match showed up — surfaced in the Mini App so the user knows what to tune.
json.job do
  json.id @job.id
  json.title @job.title
  json.company_name @job.company_name
  json.category @job.category
  json.tags @job.tags
  json.location @job.location
  json.remote @job.remote
  json.employment_type @job.employment_type
  json.url @job.url
end
