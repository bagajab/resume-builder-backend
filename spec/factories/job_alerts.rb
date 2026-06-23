# frozen_string_literal: true

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
