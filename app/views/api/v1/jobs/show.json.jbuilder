# frozen_string_literal: true

json.partial! 'api/v1/jobs/job', job: @job

# Descriptions are scraped HTML from third-party sites — sanitize before exposing
# so the client can render them safely.
json.description sanitize(@job.description)

# AI-enriched detail. ai_description is model-generated plain text (already safe).
json.ai_description @job.ai_description
json.preferred_skills @job.preferred_skills
json.benefits @job.benefits
json.responsibilities @job.responsibilities
json.qualifications @job.qualifications
json.application_instructions @job.application_instructions
json.enrichment_status @job.enrichment_status
json.enriched_at @job.enriched_at

json.metadata @job.metadata
json.first_seen_at @job.first_seen_at
json.last_seen_at @job.last_seen_at
