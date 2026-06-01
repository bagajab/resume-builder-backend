# frozen_string_literal: true

class Resume < ApplicationRecord
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
      version: version + 1
    )
    dup_resume.save!

    duplicate_associations_to(dup_resume)
    dup_resume
  end

  private

  def assign_default_template
    self.template ||= Template.find_by(slug: 'classic')
  end

  def duplicate_associations_to(dup_resume)
    if profile.present?
      dup_resume.create_profile!(profile.attributes.except('id', 'resume_id', 'created_at', 'updated_at'))
    end

    experiences.find_each { |record| dup_resume.experiences.create!(record.attributes.except('id', 'resume_id', 'created_at', 'updated_at')) }
    educations.find_each { |record| dup_resume.educations.create!(record.attributes.except('id', 'resume_id', 'created_at', 'updated_at')) }
    certifications.find_each { |record| dup_resume.certifications.create!(record.attributes.except('id', 'resume_id', 'created_at', 'updated_at')) }
    skills.find_each { |record| dup_resume.skills.create!(record.attributes.except('id', 'resume_id', 'created_at', 'updated_at')) }
    projects.find_each { |record| dup_resume.projects.create!(record.attributes.except('id', 'resume_id', 'created_at', 'updated_at')) }
  end
end
