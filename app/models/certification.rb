# frozen_string_literal: true

class Certification < ApplicationRecord
  belongs_to :resume

  validates :name, presence: true
end
