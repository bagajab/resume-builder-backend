# frozen_string_literal: true

# == Schema Information
#
# Table name: experiences
#
#  id               :bigint           not null, primary key
#  achievements     :jsonb            not null
#  company          :string           not null
#  current          :boolean          default(FALSE), not null
#  end_date         :date
#  job_title        :string           not null
#  location         :string
#  position         :integer          default(0), not null
#  responsibilities :jsonb            not null
#  start_date       :date
#  technologies     :jsonb            not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  resume_id        :bigint           not null
#
# Indexes
#
#  index_experiences_on_resume_id  (resume_id)
#
# Foreign Keys
#
#  fk_rails_...  (resume_id => resumes.id)
#
class Experience < ApplicationRecord
  belongs_to :resume

  validates :job_title, :company, presence: true
  validates :job_title, :company, length: { maximum: 120 }
  validates :location, length: { maximum: 120 }, allow_blank: true
  validate :end_date_after_start_date

  private

  def end_date_after_start_date
    return if current? || start_date.blank? || end_date.blank? || end_date >= start_date

    errors.add(:end_date, "must be after the start date")
  end
end
