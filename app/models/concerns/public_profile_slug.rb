# frozen_string_literal: true

module PublicProfileSlug
  extend ActiveSupport::Concern

  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  RESERVED_SLUGS = %w[
    admin api www app dashboard login signup settings profile preview
    resume-builder layout-designer contact about features pricing templates
    google forgot-password reset-password en tr site static cdn mail ftp
    assets rails _next vercel
  ].freeze

  class_methods do
    def normalize_public_slug(value)
      value.to_s.strip.downcase.gsub(/\s+/, '-').gsub(/[^a-z0-9-]/, '').squeeze('-').gsub(/\A-+|-+\z/, '')
    end

    def slug_available?(slug, excluding_id: nil)
      normalized = normalize_public_slug(slug)
      return false if normalized.blank?
      return false if RESERVED_SLUGS.include?(normalized)
      return false unless SLUG_FORMAT.match?(normalized)

      scope = where(public_slug: normalized)
      scope = scope.where.not(id: excluding_id) if excluding_id.present?
      !scope.exists?
    end
  end

  included do
    before_validation :normalize_public_slug_value

    validates :public_slug,
              format: { with: SLUG_FORMAT, allow_blank: true, message: 'must be lowercase letters, numbers, and hyphens' },
              uniqueness: { allow_blank: true },
              exclusion: { in: RESERVED_SLUGS, allow_blank: true, message: 'is reserved' }

    validates :public_slug, presence: true, if: :public_profile_enabled?

    validate :public_slug_available, if: -> { public_slug.present? && (public_slug_changed? || public_profile_enabled_changed?) }

    scope :publicly_visible, -> { where(public_profile_enabled: true).where.not(public_slug: [nil, '']) }
  end

  def public_profile_url(host: ENV.fetch('PUBLIC_PROFILE_HOST', 'resume.et'))
    return nil unless public_profile_enabled? && public_slug.present?

    "https://#{public_slug}.#{host}"
  end

  private

  def normalize_public_slug_value
    self.public_slug = self.class.normalize_public_slug(public_slug) if public_slug.present?
  end

  def public_slug_available
    return if self.class.slug_available?(public_slug, excluding_id: id)

    errors.add(:public_slug, 'is already taken')
  end
end
