# frozen_string_literal: true

FactoryBot.define do
  # Shared shape for every lookup table; `normalized_value` is derived by the model.
  %i[country city job_title industry degree field_of_study technology language
     language_proficiency interest].each do |name|
    factory name do
      sequence(:value) { |n| "#{name.to_s.titleize} #{n}" }
      status { 'approved' }
    end
  end

  factory :skill_option do
    sequence(:value) { |n| "Skill #{n}" }
    category { 'technical' }
    status { 'approved' }
  end
end
