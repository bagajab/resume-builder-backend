# frozen_string_literal: true

# == Schema Information
#
# Table name: certifications
#
#  id          :bigint           not null, primary key
#  expiry_date :date
#  issue_date  :date
#  issuer      :string
#  name        :string           not null
#  position    :integer          default(0), not null
#  url         :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  resume_id   :bigint           not null
#
# Indexes
#
#  index_certifications_on_resume_id  (resume_id)
#
# Foreign Keys
#
#  fk_rails_...  (resume_id => resumes.id)
#
class Certification < ApplicationRecord
  belongs_to :resume

  validates :name, presence: true
end
