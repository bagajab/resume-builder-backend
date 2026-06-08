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
end
