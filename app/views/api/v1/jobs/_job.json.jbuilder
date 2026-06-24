# frozen_string_literal: true

json.id job.id
json.source job.source
json.title job.title
json.company_name job.company_name
json.company_logo_url job.company_logo_url
json.location job.location
json.region job.region
json.remote job.remote
json.employment_type job.employment_type
json.category job.category
json.experience_level job.experience_level
json.education_level job.education_level
json.salary job.salary
json.summary job.summary
json.tags job.tags

# AI-enriched, normalized facets (null until the enrichment job runs).
json.ai_summary job.ai_summary
json.seniority job.seniority
json.remote_type job.remote_type
json.salary_min job.salary_min
json.salary_max job.salary_max
json.salary_currency job.salary_currency
json.salary_period job.salary_period
json.experience_years_min job.experience_years_min
json.skills job.skills
json.languages job.languages

json.posted_on job.posted_on
json.deadline_on job.deadline_on
json.url job.url
json.apply_url job.apply_url
json.active job.active
