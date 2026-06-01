# frozen_string_literal: true

class ResumeProfile < ApplicationRecord
  belongs_to :resume

  validates :resume_id, uniqueness: true
end
