# frozen_string_literal: true

class Education < ApplicationRecord
  belongs_to :resume

  validates :institution, presence: true
end
