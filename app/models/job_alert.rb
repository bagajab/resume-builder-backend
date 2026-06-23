# frozen_string_literal: true

# A user-defined subscription describing the kind of jobs they want to hear about.
# JobAlerts::ScanService compares active alerts against newly-scraped Job records
# (via JobAlerts::Matcher) and records a JobAlertNotification per match.
class JobAlert < ApplicationRecord
  REMOTE_PREFERENCES = %w[any remote on_site hybrid].freeze

  belongs_to :user
  has_many :job_alert_notifications, dependent: :destroy
  has_many :jobs, through: :job_alert_notifications

  enum :frequency, { instant: 0, daily: 1, weekly: 2 }
  enum :status, { active: 0, paused: 1 }

  validates :name, presence: true
  validates :remote_preference, inclusion: { in: REMOTE_PREFERENCES }
  validate :salary_range_consistent

  private

  def salary_range_consistent
    return if salary_min.blank? || salary_max.blank?

    errors.add(:salary_max, :greater_than_or_equal_to, count: salary_min) if salary_max < salary_min
  end
end
