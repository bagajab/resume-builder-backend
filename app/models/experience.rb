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
end
