# frozen_string_literal: true

# == Schema Information
#
# Table name: templates
#
#  id          :bigint           not null, primary key
#  description :text
#  name        :string           not null
#  slug        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_templates_on_slug  (slug) UNIQUE
#
FactoryBot.define do
  factory :template do
    sequence(:name) { |n| "Template #{n}" }
    sequence(:slug) { |n| "template-#{n}" }
  end
end
