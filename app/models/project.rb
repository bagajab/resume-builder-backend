# frozen_string_literal: true

# == Schema Information
#
# Table name: projects
#
#  id          :bigint           not null, primary key
#  date        :string
#  description :text
#  position    :integer          default(0), not null
#  role        :string
#  title       :string           not null
#  url         :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  resume_id   :bigint           not null
#
# Indexes
#
#  index_projects_on_resume_id  (resume_id)
#
# Foreign Keys
#
#  fk_rails_...  (resume_id => resumes.id)
#
class Project < ApplicationRecord
  belongs_to :resume

  validates :title, presence: true
end
