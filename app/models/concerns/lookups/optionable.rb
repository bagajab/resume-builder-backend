# frozen_string_literal: true

module Lookups
  # Shared behaviour for the resume-editor lookup tables (Country, City, JobTitle,
  # …). Every option carries a human `value`, a `normalized_value` used for
  # case/whitespace-insensitive dedupe, and a moderation `status`: admin-curated
  # rows are `approved`, while values typed by end-users land as `pending` until an
  # admin approves them in ActiveAdmin.
  #
  # `search` is trigram-backed (see the GIN `gin_trgm_ops` indexes in
  # CreateLookupTables): an indexed substring/fuzzy match ranked by similarity, so
  # the dropdown stays fast as the lists grow.
  module Optionable
    extend ActiveSupport::Concern

    STATUSES = %w[approved pending rejected].freeze

    included do
      belongs_to :submitted_by_user, class_name: 'User', optional: true

      before_validation :normalize_value

      validates :value, presence: true, length: { maximum: 255 }
      validates :status, inclusion: { in: STATUSES }

      if table_exists? && column_names.include?('category')
        validates :normalized_value, presence: true, uniqueness: { scope: :category, case_sensitive: false }
      else
        validates :normalized_value, presence: true, uniqueness: { case_sensitive: false }
      end

      scope :approved, -> { where(status: 'approved') }
      scope :pending,  -> { where(status: 'pending') }
      scope :ordered,  -> { order(position: :desc, usage_count: :desc, value: :asc) }
      scope :by_category, ->(category) { with_category(category) }
      scope :search, ->(term) { matching(term) }

      # Whitelist the columns ActiveAdmin filters/sorts on (see app/models/concerns/
      # ransackable.rb). Without this, Ransack raises on `value_cont` etc.
      allowed = table_exists? ? column_names : []
      const_set(:RANSACK_ATTRIBUTES, (allowed & %w[
        id value normalized_value status category usage_count position
        submitted_by_user_id created_at updated_at
      ]).freeze)
      const_set(:RANSACK_ASSOCIATIONS, %w[submitted_by_user].freeze)
    end

    # Narrow by category only for models that have the column (skill_options);
    # a no-op everywhere else so callers can stay uniform.
    class_methods do
      def with_category(category)
        return all unless column_names.include?('category') && category.present?

        where(category: category.to_s)
      end

      # Indexed substring match (ILIKE, accelerated by the trigram GIN index) OR a
      # fuzzy trigram match, ranked by similarity then popularity. Capped so the
      # endpoint never returns an unbounded list to the dropdown.
      def matching(term)
        q = term.to_s.strip
        return all if q.blank?

        quoted = connection.quote(q)
        where('value ILIKE :contains OR value % :q', contains: "%#{sanitize_sql_like(q)}%", q: q)
          .reorder(Arel.sql("similarity(value, #{quoted}) DESC, usage_count DESC, value ASC"))
          .limit(20)
      end

      # Canonical form used for case/whitespace-insensitive dedupe. Shared with the
      # controller so a looked-up row and a freshly-typed value collapse together.
      def normalize_value(value)
        value.to_s.downcase.strip.gsub(/\s+/, ' ')
      end
    end

    private

    def normalize_value
      self.normalized_value = self.class.normalize_value(value)
    end
  end
end
