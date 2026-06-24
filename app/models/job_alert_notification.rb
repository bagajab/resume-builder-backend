# frozen_string_literal: true

# The record that a given Job matched a given JobAlert. Doubles as the dedup ledger
# (unique on [job_alert_id, job_id]) and the per-channel delivery log.
# == Schema Information
#
# Table name: job_alert_notifications
#
#  id                       :bigint           not null, primary key
#  channel                  :string           default("telegram"), not null
#  error                    :text
#  feedback                 :string
#  feedback_at              :datetime
#  match_score              :float
#  refine_token_consumed_at :datetime
#  refine_token_jti         :string
#  sent_at                  :datetime
#  status                   :integer          default("pending"), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  job_alert_id             :bigint           not null
#  job_id                   :bigint           not null
#  telegram_message_id      :bigint
#  user_id                  :bigint           not null
#
# Indexes
#
#  index_job_alert_notifications_on_job_alert_id             (job_alert_id)
#  index_job_alert_notifications_on_job_alert_id_and_job_id  (job_alert_id,job_id) UNIQUE
#  index_job_alert_notifications_on_job_id                   (job_id)
#  index_job_alert_notifications_on_user_id                  (user_id)
#  index_job_alert_notifications_on_user_id_and_status       (user_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (job_alert_id => job_alerts.id)
#  fk_rails_...  (job_id => jobs.id)
#  fk_rails_...  (user_id => users.id)
#
class JobAlertNotification < ApplicationRecord
  FEEDBACKS = %w[positive negative].freeze

  belongs_to :job_alert
  belongs_to :job
  belongs_to :user

  enum :status, { pending: 0, sent: 1, failed: 2, skipped: 3 }

  validates :job_id, uniqueness: { scope: :job_alert_id }
  validates :feedback, inclusion: { in: FEEDBACKS }, allow_nil: true

  def feedback_given?
    feedback.present?
  end

  # Records the user's 👍/👎 on this match. update_column avoids re-validating the
  # (otherwise untouched) row and is safe — the values are server-controlled.
  def record_feedback!(value)
    raise ArgumentError, "unknown feedback #{value.inspect}" unless FEEDBACKS.include?(value.to_s)

    update_columns(feedback: value.to_s, feedback_at: Time.current, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  # True while a refine token with this id is the current, unconsumed one.
  def refine_token_active?(jti)
    refine_token_jti.present? && refine_token_consumed_at.nil? &&
      ActiveSupport::SecurityUtils.secure_compare(refine_token_jti, jti.to_s)
  end

  def consume_refine_token!
    update_columns(refine_token_consumed_at: Time.current, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end
end
