# frozen_string_literal: true

json.partial! 'api/v1/jobs/job', job: @job

# Descriptions are scraped HTML from third-party sites — sanitize before exposing
# so the client can render them safely.
json.description sanitize(@job.description)
json.metadata @job.metadata
json.first_seen_at @job.first_seen_at
json.last_seen_at @job.last_seen_at
