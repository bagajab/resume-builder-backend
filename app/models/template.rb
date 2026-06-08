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
class Template < ApplicationRecord
  has_many :resumes, dependent: :restrict_with_error

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  scope :ordered, -> { order(:name) }
end
