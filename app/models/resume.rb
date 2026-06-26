# frozen_string_literal: true

# == Schema Information
#
# Table name: resumes
#
#  id                     :bigint           not null, primary key
#  current_step           :integer          default(1), not null
#  layout_config          :jsonb            not null
#  public_profile_enabled :boolean          default(FALSE), not null
#  public_slug            :string
#  published_at           :datetime
#  status                 :string           default("draft"), not null
#  title                  :string           default("Untitled Resume"), not null
#  version                :integer          default(1), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  source_resume_id       :bigint
#  template_id            :bigint           not null
#  user_id                :bigint           not null
#
# Indexes
#
#  index_resumes_on_public_profile_enabled  (public_profile_enabled) WHERE (public_profile_enabled = true)
#  index_resumes_on_public_slug             (public_slug) UNIQUE WHERE (public_slug IS NOT NULL)
#  index_resumes_on_source_resume_id        (source_resume_id)
#  index_resumes_on_template_id             (template_id)
#  index_resumes_on_user_id                 (user_id)
#  index_resumes_on_user_id_and_status      (user_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (source_resume_id => resumes.id)
#  fk_rails_...  (template_id => templates.id)
#  fk_rails_...  (user_id => users.id)
#
class Resume < ApplicationRecord
  include PublicProfileSlug

  STATUSES = %w[draft completed].freeze
  STEPS = 6

  belongs_to :user
  belongs_to :template
  belongs_to :source_resume, class_name: 'Resume', optional: true

  has_one :profile, class_name: 'ResumeProfile', dependent: :destroy
  has_many :experiences, dependent: :destroy
  has_many :educations, dependent: :destroy
  has_many :certifications, dependent: :destroy
  has_many :skills, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :derived_resumes, class_name: 'Resume', foreign_key: :source_resume_id, dependent: :nullify, inverse_of: :source_resume

  accepts_nested_attributes_for :profile, update_only: true
  accepts_nested_attributes_for :experiences, allow_destroy: true
  accepts_nested_attributes_for :educations, allow_destroy: true
  accepts_nested_attributes_for :certifications, allow_destroy: true
  accepts_nested_attributes_for :skills, allow_destroy: true
  accepts_nested_attributes_for :projects, allow_destroy: true

  validates :title, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :template, presence: true
  validates :current_step, numericality: { greater_than: 0, less_than_or_equal_to: STEPS }

  scope :ordered, -> { order(updated_at: :desc) }
  scope :originals, -> { where(source_resume_id: nil) }

  before_validation :assign_default_template, on: :create
  before_save :sync_published_at

  def template_slug
    template&.slug
  end

  def assign_template_by_slug(slug)
    self.template = Template.find_by!(slug: slug)
  end

  def duplicate_for(user)
    dup_resume = dup
    dup_resume.assign_attributes(
      user:,
      source_resume: self,
      title: "#{title} (Copy)",
      status: 'draft',
      version: version + 1,
      public_slug: nil,
      public_profile_enabled: false,
      published_at: nil
    )
    dup_resume.save!

    duplicate_associations_to(dup_resume)
    dup_resume
  end

  private

  def assign_default_template
    self.template ||= Template.find_by(slug: 'spotlight')
  end

  def sync_published_at
    return unless public_profile_enabled_changed?

    self.published_at = public_profile_enabled? ? (published_at || Time.current) : published_at
  end

  def duplicate_associations_to(dup_resume)
    if profile.present?
      dup_profile = dup_resume.create_profile!(profile.attributes.except('id', 'resume_id', 'created_at', 'updated_at'))
      dup_profile.photo.attach(profile.photo.blob) if profile.photo.attached?
    end

    experiences.find_each { |record| dup_resume.experiences.create!(record.attributes.except('id', 'resume_id', 'created_at', 'updated_at')) }
    educations.find_each { |record| dup_resume.educations.create!(record.attributes.except('id', 'resume_id', 'created_at', 'updated_at')) }
    certifications.find_each { |record| dup_resume.certifications.create!(record.attributes.except('id', 'resume_id', 'created_at', 'updated_at')) }
    skills.find_each { |record| dup_resume.skills.create!(record.attributes.except('id', 'resume_id', 'created_at', 'updated_at')) }
    projects.find_each { |record| dup_resume.projects.create!(record.attributes.except('id', 'resume_id', 'created_at', 'updated_at')) }
  end
end
