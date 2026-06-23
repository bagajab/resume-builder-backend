# frozen_string_literal: true

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
