# frozen_string_literal: true

module Jobs
  class Enricher
    # Coerces the model's raw JSON into a hash of assignable Job attributes,
    # forcing every value past the model's validations and into the controlled
    # vocabularies (so a slightly-off generation never fails the update or stores a
    # non-canonical category/enum). Keys map to Job columns; `summary` /
    # `clean_description` are routed to the `ai_*` columns to preserve the source.
    module Normalizer
      STRING_LIMITS = { ai_summary: 800, ai_description: 12_000, education_level: 120,
                        salary_currency: 8, application_instructions: 1_500 }.freeze
      LIST_MAX = 25
      LIST_ITEM_LENGTH = 200
      SALARY_CAP = 1_000_000_000

      module_function

      def call(raw)
        raw = raw.to_h
        {
          ai_summary: string(raw['summary'], STRING_LIMITS[:ai_summary]),
          ai_description: string(raw['clean_description'], STRING_LIMITS[:ai_description]),
          category: category(raw['category']),
          employment_type: enum(raw['employment_type'], Job::EMPLOYMENT_TYPES),
          seniority: enum(raw['seniority'], Job::SENIORITY_LEVELS),
          experience_years_min: integer(raw['experience_years_min'], 0, 60),
          education_level: string(raw['education_level'], STRING_LIMITS[:education_level]),
          remote_type: enum(raw['remote_type'], Job::REMOTE_TYPES),
          salary_currency: string(raw['salary_currency'], STRING_LIMITS[:salary_currency])&.upcase,
          salary_period: enum(raw['salary_period'], Job::SALARY_PERIODS),
          skills: list(raw['skills']),
          preferred_skills: list(raw['preferred_skills']),
          languages: list(raw['languages']),
          benefits: list(raw['benefits']),
          responsibilities: list(raw['responsibilities'], length: LIST_ITEM_LENGTH),
          qualifications: list(raw['qualifications'], length: LIST_ITEM_LENGTH),
          application_instructions: string(raw['application_instructions'], STRING_LIMITS[:application_instructions])
        }.merge(salary_range(raw))
      end

      def string(value, limit)
        text = value.to_s.gsub(/\s+/, ' ').strip
        return if text.blank?

        text.length > limit ? text[0, limit].rstrip : text
      end

      # Forces enums to a known lowercase value, else nil — so an out-of-vocabulary
      # generation can never trip the model's inclusion validation.
      def enum(value, allowed)
        normalized = value.to_s.strip.downcase
        allowed.include?(normalized) ? normalized : nil
      end

      # Always returns a canonical category (the model is told to pick one). Falls
      # back to a case-insensitive match, then "Other".
      def category(value)
        text = value.to_s.strip
        return 'Other' if text.blank?
        return text if Job::CATEGORIES.include?(text)

        Job::CATEGORIES.find { |canonical| canonical.casecmp?(text) } || 'Other'
      end

      def integer(value, min, max)
        int = Integer(value, exception: false)
        return if int.nil? || int < min || int > max

        int
      end

      def list(value, length: 80)
        Array(value)
          .filter_map { |item| string(item, length) }
          .uniq
          .first(LIST_MAX)
      end

      # Clears an inverted range (max < min) and an only-min/only-max stays as given.
      def salary_range(raw)
        min = integer(raw['salary_min'], 0, SALARY_CAP)
        max = integer(raw['salary_max'], 0, SALARY_CAP)
        max = nil if min && max && max < min
        { salary_min: min, salary_max: max }
      end
    end
  end
end
