# frozen_string_literal: true

json.resumes @resumes do |resume|
  json.id           resume.id
  json.title        resume.title
  json.current_step resume.current_step
  json.status       resume.status
  json.version      resume.version
  json.updated_at   resume.updated_at
  json.full_name    resume.profile&.full_name
  json.public_slug  resume.public_slug
  json.public_profile_enabled resume.public_profile_enabled
end
