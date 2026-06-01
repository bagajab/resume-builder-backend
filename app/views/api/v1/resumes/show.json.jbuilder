# frozen_string_literal: true

json.resume do
  json.partial! 'api/v1/resumes/resume', resume: @resume
end
