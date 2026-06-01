# frozen_string_literal: true

json.id           resume.id
json.title        resume.title
json.current_step resume.current_step
json.status       resume.status
json.version      resume.version
json.template_id  resume.template.slug
json.template do
  json.partial! 'api/v1/templates/template', template: resume.template
end
json.layout_config resume.layout_config
json.source_resume_id resume.source_resume_id
json.created_at   resume.created_at
json.updated_at   resume.updated_at

if resume.profile.present?
  json.profile do
    json.partial! 'api/v1/resume_profiles/profile', profile: resume.profile
  end
else
  json.profile nil
end

json.experiences resume.experiences.sort_by(&:position) do |experience|
  json.partial! 'api/v1/experiences/experience', experience:
end

json.educations resume.educations.sort_by(&:position) do |education|
  json.partial! 'api/v1/educations/education', education:
end

json.certifications resume.certifications.sort_by(&:position) do |certification|
  json.partial! 'api/v1/certifications/certification', certification:
end

json.skills resume.skills.sort_by(&:position) do |skill|
  json.partial! 'api/v1/skills/skill', skill:
end

json.projects resume.projects.sort_by(&:position) do |project|
  json.partial! 'api/v1/projects/project', project:
end
