# frozen_string_literal: true

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
FactoryBot.define do
  factory :job_alert do
    user
    sequence(:name) { |n| "Alert #{n}" }
    titles { ['Software Engineer'] }
    keywords { [] }
    locations { [] }
    experience_levels { [] }
    employment_types { [] }
    remote_preference { 'any' }
    frequency { :instant }
    status { :active }

    trait :daily do
      frequency { :daily }
    end

    trait :weekly do
      frequency { :weekly }
    end

    trait :paused do
      status { :paused }
    end
  end
end
