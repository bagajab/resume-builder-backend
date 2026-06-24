# frozen_string_literal: true

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
FactoryBot.define do
  factory :job_alert_notification do
    job_alert
    job
    user { job_alert.user }
    match_score { 0.8 }
    channel { 'telegram' }
    status { :pending }

    trait :sent do
      status { :sent }
      sent_at { Time.current }
    end
  end
end
