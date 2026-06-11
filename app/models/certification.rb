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
  URL_FORMAT = %r{\Ahttps?://}.freeze

  belongs_to :resume

  validates :name, presence: true
  validates :name, :issuer, length: { maximum: 160 }, allow_blank: true
  validates :url,
            format: { with: URL_FORMAT, message: "must start with http:// or https://" },
            allow_blank: true
  validate :expiry_date_after_issue_date

  private

  def expiry_date_after_issue_date
    return if issue_date.blank? || expiry_date.blank? || expiry_date >= issue_date

    errors.add(:expiry_date, "must be after the issue date")
  end
end
