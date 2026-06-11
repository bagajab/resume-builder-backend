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
  URL_FORMAT = %r{\Ahttps?://}.freeze
  ALLOWED_PHOTO_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze
  MAX_PHOTO_SIZE = 5.megabytes

  belongs_to :resume
  has_one_attached :photo

  validates :resume_id, uniqueness: true
  validate :acceptable_photo
  validates :full_name, :job_title, :industry, length: { maximum: 120 }, allow_blank: true
  validates :phone, length: { maximum: 40 }, allow_blank: true
  validates :location_city, :location_country, length: { maximum: 80 }, allow_blank: true
  validates :career_summary, length: { maximum: 1_200 }, allow_blank: true
  validates :years_of_experience, numericality: { in: 0..60 }, allow_nil: true
  validates :linkedin_url, :github_url, :portfolio_url,
            format: { with: URL_FORMAT, message: "must start with http:// or https://" },
            allow_blank: true

  def photo_url
    return unless photo.attached?

    Rails.application.routes.url_helpers.rails_blob_url(photo, **blob_url_options)
  end

  private

  def blob_url_options
    host = ENV.fetch('SERVER_HOST', 'localhost')
    port = ENV.fetch('PORT', 3000).to_i
    opts = { host:, protocol: Rails.env.production? ? 'https' : 'http' }
    opts[:port] = port unless port == 80
    opts
  end

  def acceptable_photo
    return unless photo.attached?

    unless photo.content_type.in?(ALLOWED_PHOTO_TYPES)
      errors.add(:photo, 'must be a JPEG, PNG, WebP, or GIF image')
    end

    return unless photo.byte_size > MAX_PHOTO_SIZE

    errors.add(:photo, 'must be smaller than 5 MB')
  end
end
