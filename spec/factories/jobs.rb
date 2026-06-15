# frozen_string_literal: true

# == Schema Information
#
# Table name: jobs
#
#  id               :bigint           not null, primary key
#  active           :boolean          default(TRUE), not null
#  apply_url        :string
#  category         :string
#  company_logo_url :string
#  company_name     :string
#  deadline_on      :date
#  description      :text
#  education_level  :string
#  employment_type  :string
#  experience_level :string
#  first_seen_at    :datetime         not null
#  last_seen_at     :datetime         not null
#  location         :string
#  metadata         :jsonb            not null
#  posted_on        :date
#  region           :string
#  remote           :boolean          default(FALSE), not null
#  salary           :string
#  source           :string           not null
#  source_uid       :string
#  summary          :text
#  tags             :string           default([]), not null, is an Array
#  title            :string           not null
#  url              :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_jobs_on_active                 (active)
#  index_jobs_on_deadline_on            (deadline_on)
#  index_jobs_on_posted_on              (posted_on)
#  index_jobs_on_source                 (source)
#  index_jobs_on_source_and_source_uid  (source,source_uid)
#  index_jobs_on_tags                   (tags) USING gin
#  index_jobs_on_url                    (url) UNIQUE
#
FactoryBot.define do
  factory :job do
    source { 'ethiojobs' }
    sequence(:url) { |n| "https://ethiojobs.net/jobs/job-#{n}" }
    title { Faker::Job.title }
    company_name { Faker::Company.name }
    location { 'Addis Ababa' }
    region { 'Addis Ababa' }
    employment_type { 'full_time' }
    remote { false }
    active { true }
    first_seen_at { Time.current }
    last_seen_at { Time.current }
    posted_on { Date.current }
    deadline_on { 3.weeks.from_now.to_date }

    trait :remote do
      remote { true }
    end

    trait :expired do
      deadline_on { 2.days.ago.to_date }
    end

    trait :inactive do
      active { false }
    end
  end
end
