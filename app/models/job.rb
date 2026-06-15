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
class Job < ApplicationRecord
  # Job boards we aggregate. Keep in sync with the scraper registry in
  # Jobs::ScraperService.
  SOURCES = %w[ethiojobs ethiopian_reporter hahu_jobs].freeze

  EMPLOYMENT_TYPES = %w[
    full_time part_time contract temporary internship freelance volunteer other
  ].freeze

  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :url, presence: true, uniqueness: true
  validates :title, presence: true
  validates :employment_type, inclusion: { in: EMPLOYMENT_TYPES }, allow_nil: true

  scope :live, -> { where(active: true) }
  scope :from_source, ->(source) { where(source:) }
  scope :remote, -> { where(remote: true) }
  scope :search, lambda { |term|
    pattern = "%#{sanitize_sql_like(term.to_s.strip)}%"
    where(
      'title ILIKE :q OR company_name ILIKE :q OR description ILIKE :q OR category ILIKE :q',
      q: pattern
    )
  }
  scope :open_for_application, lambda {
    where('deadline_on IS NULL OR deadline_on >= ?', Date.current)
  }
  # Newest first, treating a missing posted_on as the day we first saw it.
  scope :recent, -> { order(Arel.sql('COALESCE(posted_on, first_seen_at::date) DESC, id DESC')) }

  def expired?
    deadline_on.present? && deadline_on < Date.current
  end

  def days_until_deadline
    return if deadline_on.blank?

    (deadline_on - Date.current).to_i
  end
end
