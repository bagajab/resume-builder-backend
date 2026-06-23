# frozen_string_literal: true

json.count @jobs.size
json.jobs @jobs do |job|
  json.partial! 'api/v1/jobs/job', job:
end
