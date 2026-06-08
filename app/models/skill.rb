# frozen_string_literal: true

# == Schema Information
#
# Table name: skills
#
#  id         :bigint           not null, primary key
#  category   :string           default("technical"), not null
#  color      :string
#  level      :integer
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  resume_id  :bigint           not null
#
# Indexes
#
#  index_skills_on_resume_id               (resume_id)
#  index_skills_on_resume_id_and_category  (resume_id,category)
#
# Foreign Keys
#
#  fk_rails_...  (resume_id => resumes.id)
#
class Skill < ApplicationRecord
  CATEGORIES = %w[technical soft tools].freeze

  belongs_to :resume

  validates :name, presence: true
  validates :category, inclusion: { in: CATEGORIES }
  validates :level, numericality: { in: 0..100 }, allow_nil: true
end
