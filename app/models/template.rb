# frozen_string_literal: true

class Template < ApplicationRecord
  has_many :resumes, dependent: :restrict_with_error

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  scope :ordered, -> { order(:name) }
end
