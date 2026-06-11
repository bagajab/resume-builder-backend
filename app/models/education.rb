# frozen_string_literal: true

# == Schema Information
#
# Table name: educations
#
#  id             :bigint           not null, primary key
#  degree         :string
#  end_year       :integer
#  field_of_study :string
#  gpa            :string
#  honors         :string
#  institution    :string           not null
#  position       :integer          default(0), not null
#  start_year     :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  resume_id      :bigint           not null
#
# Indexes
#
#  index_educations_on_resume_id  (resume_id)
#
# Foreign Keys
#
#  fk_rails_...  (resume_id => resumes.id)
#
class Education < ApplicationRecord
  belongs_to :resume

  validates :institution, presence: true
  validates :institution, :degree, :field_of_study, length: { maximum: 160 }, allow_blank: true
  validates :start_year, :end_year, numericality: { in: 1900..2100 }, allow_nil: true
  validate :end_year_after_start_year

  private

  def end_year_after_start_year
    return if start_year.blank? || end_year.blank? || end_year >= start_year

    errors.add(:end_year, "must be after the start year")
  end
end
