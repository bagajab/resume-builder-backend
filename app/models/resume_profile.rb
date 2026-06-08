# frozen_string_literal: true

# == Schema Information
#
# Table name: resume_profiles
#
#  id                    :bigint           not null, primary key
#  awards                :jsonb            not null
#  career_summary        :text
#  full_name             :string
#  github_url            :string
#  industry              :string
#  interests             :jsonb            not null
#  job_preferences       :jsonb            not null
#  job_title             :string
#  languages             :jsonb            not null
#  linkedin_url          :string
#  location_city         :string
#  location_country      :string
#  phone                 :string
#  portfolio_url         :string
#  references            :jsonb            not null
#  volunteer_experiences :jsonb            not null
#  years_of_experience   :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  resume_id             :bigint           not null
#
# Indexes
#
#  index_resume_profiles_on_resume_id  (resume_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (resume_id => resumes.id)
#
class ResumeProfile < ApplicationRecord
  belongs_to :resume

  validates :resume_id, uniqueness: true
end
