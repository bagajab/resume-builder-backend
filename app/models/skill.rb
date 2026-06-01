# frozen_string_literal: true

class Skill < ApplicationRecord
  CATEGORIES = %w[technical soft tools].freeze

  belongs_to :resume

  validates :name, presence: true
  validates :category, inclusion: { in: CATEGORIES }
end
