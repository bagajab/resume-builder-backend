# frozen_string_literal: true

class Experience < ApplicationRecord
  belongs_to :resume

  validates :job_title, :company, presence: true
end
