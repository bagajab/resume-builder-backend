# frozen_string_literal: true

# == Schema Information
#
# Table name: jobs
#
#  id                       :bigint           not null, primary key
#  active                   :boolean          default(TRUE), not null
#  ai_description           :text
#  ai_summary               :text
#  application_instructions :text
#  apply_url                :string
#  benefits                 :string           default([]), not null, is an Array
#  category                 :string
#  company_logo_url         :string
#  company_name             :string
#  content_hash             :string
#  deadline_on              :date
#  description              :text
#  education_level          :string
#  employment_type          :string
#  enriched_at              :datetime
#  enrichment_model         :string
#  enrichment_status        :string           default("pending"), not null
#  enrichment_version       :integer
#  experience_level         :string
#  experience_years_min     :integer
#  first_seen_at            :datetime         not null
#  languages                :string           default([]), not null, is an Array
#  last_seen_at             :datetime         not null
#  location                 :string
#  metadata                 :jsonb            not null
#  posted_on                :date
#  preferred_skills         :string           default([]), not null, is an Array
#  qualifications           :text             default([]), not null, is an Array
#  region                   :string
#  remote                   :boolean          default(FALSE), not null
#  remote_type              :string
#  responsibilities         :text             default([]), not null, is an Array
#  salary                   :string
#  salary_currency          :string
#  salary_max               :integer
#  salary_min               :integer
#  salary_period            :string
#  seniority                :string
#  skills                   :string           default([]), not null, is an Array
#  source                   :string           not null
#  source_uid               :string
#  summary                  :text
#  tags                     :string           default([]), not null, is an Array
#  title                    :string           not null
#  url                      :string           not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_jobs_on_active                 (active)
#  index_jobs_on_content_hash           (content_hash)
#  index_jobs_on_deadline_on            (deadline_on)
#  index_jobs_on_enrichment_status      (enrichment_status)
#  index_jobs_on_languages              (languages) USING gin
#  index_jobs_on_posted_on              (posted_on)
#  index_jobs_on_remote_type            (remote_type)
#  index_jobs_on_seniority              (seniority)
#  index_jobs_on_skills                 (skills) USING gin
#  index_jobs_on_source                 (source)
#  index_jobs_on_source_and_source_uid  (source,source_uid)
#  index_jobs_on_tags                   (tags) USING gin
#  index_jobs_on_url                    (url) UNIQUE
#
class Job < ApplicationRecord
  # Job boards we aggregate. Keep in sync with the scraper registry in
  # Jobs::ScraperService.
  SOURCES = %w[
    ethiojobs ethiopian_reporter hahu_jobs
    etcareers enjera ngojobs guzojobs palmjobs
  ].freeze

  EMPLOYMENT_TYPES = %w[
    full_time part_time contract temporary internship freelance volunteer other
  ].freeze

  # Canonical, controlled category taxonomy. Jobs::Enricher classifies every job
  # into exactly one of these (Gemini is told to map to the closest), so the
  # filters#categories endpoint stays stable rather than echoing messy per-source
  # category strings. Do NOT validate the raw scraped `category` against this —
  # scrapers store the source value first; enrichment overwrites it with a member
  # of this list.
  CATEGORIES = [
    'Accounting & Finance',
    'Administrative & Clerical',
    'Agriculture & Environment',
    'Arts, Media & Communications',
    'Banking & Insurance',
    'Construction & Engineering',
    'Consulting & Strategy',
    'Customer Service',
    'Education & Training',
    'Engineering & Manufacturing',
    'Healthcare & Medical',
    'Hospitality & Tourism',
    'Human Resources',
    'Information Technology',
    'Legal',
    'Logistics & Supply Chain',
    'Management & Executive',
    'Marketing & Sales',
    'NGO & Development',
    'Operations & Project Management',
    'Research & Science',
    'Retail & Wholesale',
    'Security & Protective Services',
    'Skilled Trades & Labor',
    'Other'
  ].freeze

  # Normalized seniority ladder (low → high). Populated only by enrichment.
  SENIORITY_LEVELS = %w[
    internship entry junior mid senior lead principal manager director executive
  ].freeze

  REMOTE_TYPES = %w[onsite remote hybrid].freeze
  SALARY_PERIODS = %w[hour day week month year].freeze

  # Lifecycle of the AI enrichment for a job:
  #   pending  – queued / not yet enriched (also set when source content changed)
  #   enriched – up to date for the current content_hash + enrichment_version
  #   failed   – enrichment raised after retries; eligible for a later retry
  #   skipped  – deliberately not enriched (e.g. enrichment disabled)
  ENRICHMENT_STATUSES = %w[pending enriched failed skipped].freeze

  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :url, presence: true, uniqueness: true
  validates :title, presence: true
  validates :employment_type, inclusion: { in: EMPLOYMENT_TYPES }, allow_nil: true
  validates :seniority, inclusion: { in: SENIORITY_LEVELS }, allow_nil: true
  validates :remote_type, inclusion: { in: REMOTE_TYPES }, allow_nil: true
  validates :enrichment_status, inclusion: { in: ENRICHMENT_STATUSES }

  scope :live, -> { where(active: true) }
  scope :from_source, ->(source) { where(source:) }
  scope :remote, -> { where(remote: true) }
  scope :enriched, -> { where(enrichment_status: 'enriched') }
  # Jobs that still need a (re-)enrichment pass.
  scope :awaiting_enrichment, -> { where(enrichment_status: %w[pending failed]) }
  scope :with_seniority, ->(level) { where(seniority: level) }
  # Any of the given skills present (case-sensitive ⇒ enrichment normalizes case).
  scope :with_skills, lambda { |skills|
    where('skills && ARRAY[?]::varchar[]', Array(skills))
  }
  scope :search, lambda { |term|
    pattern = "%#{sanitize_sql_like(term.to_s.strip)}%"
    where(
      'title ILIKE :q OR company_name ILIKE :q OR description ILIKE :q OR ' \
      'ai_summary ILIKE :q OR category ILIKE :q',
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

  def enriched?
    enrichment_status == 'enriched'
  end
end
