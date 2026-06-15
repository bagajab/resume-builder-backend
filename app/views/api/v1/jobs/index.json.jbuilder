# frozen_string_literal: true

json.jobs @jobs do |job|
  json.partial! 'api/v1/jobs/job', job:
end

json.meta do
  json.page @meta[:page]
  json.per @meta[:per]
  json.total @meta[:total]
  json.total_pages @meta[:total_pages]
end
