# frozen_string_literal: true

# The record that a given Job matched a given JobAlert. Doubles as the dedup ledger
# (unique on [job_alert_id, job_id]) and the per-channel delivery log.
class JobAlertNotification < ApplicationRecord
  belongs_to :job_alert
  belongs_to :job
  belongs_to :user

  enum :status, { pending: 0, sent: 1, failed: 2, skipped: 3 }

  validates :job_id, uniqueness: { scope: :job_alert_id }
end
