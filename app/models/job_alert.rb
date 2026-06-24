# frozen_string_literal: true

# A user-defined subscription describing the kind of jobs they want to hear about.
# JobAlerts::ScanService compares active alerts against newly-scraped Job records
# (via JobAlerts::Matcher) and records a JobAlertNotification per match.
# == Schema Information
#
# Table name: job_alerts
#
#  id                :bigint           not null, primary key
#  employment_types  :string           default([]), not null, is an Array
#  experience_levels :string           default([]), not null, is an Array
#  frequency         :integer          default("instant"), not null
#  keywords          :string           default([]), not null, is an Array
#  last_run_at       :datetime
#  locations         :string           default([]), not null, is an Array
#  name              :string           not null
#  remote_preference :string           default("any"), not null
#  salary_currency   :string
#  salary_max        :integer
#  salary_min        :integer
#  status            :integer          default("active"), not null
#  titles            :string           default([]), not null, is an Array
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_job_alerts_on_keywords  (keywords) USING gin
#  index_job_alerts_on_status    (status)
#  index_job_alerts_on_titles    (titles) USING gin
#  index_job_alerts_on_user_id   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
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
