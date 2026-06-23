# frozen_string_literal: true

FactoryBot.define do
  factory :template do
    sequence(:name) { |n| "Template #{n}" }
    sequence(:slug) { |n| "template-#{n}" }
  end
end
