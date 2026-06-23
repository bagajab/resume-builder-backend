# frozen_string_literal: true

module Resumes
  # Canonicalizes the free-text values the parser extracted against the curated
  # lookup tables (Lookups::Optionable models). An exact (normalized) match
  # rewrites the parsed value to the lookup's canonical casing; an unmatched
  # value is inserted as a `pending` row attributed to the user — the same
  # workflow as API::V1::LookupsController#upsert_option — so the admin
  # moderation queue and the editor's autocomplete stay in sync.
  #
  # Resume fields remain free text (no FK), so this only normalizes strings in
  # place on the parsed hash before it reaches Resumes::DraftUpdater.
  class LookupMapper
    def initialize(user:)
      @user = user
    end

    # @param parsed [Hash] the symbolized parser output (mutated in place)
    def map!(parsed)
      map_profile!(parsed[:profile])
      map_skills!(parsed[:skills])
      map_experiences!(parsed[:experiences])
      map_educations!(parsed[:educations])
      parsed
    end

    private

    def map_profile!(profile)
      return if profile.blank?

      profile[:job_title] = canonicalize(JobTitle, profile[:job_title])
      profile[:industry]  = canonicalize(Industry, profile[:industry])
      profile[:interests] = canonicalize_list(Interest, profile[:interests])
      map_languages!(profile[:languages])
    end

    def map_languages!(languages)
      Array(languages).each { |language| language[:name] = canonicalize(Language, language[:name]) }
    end

    def map_skills!(skills)
      Array(skills).each do |skill|
        category = skill[:category].presence || SkillOption::CATEGORIES.first
        skill[:name] = canonicalize(SkillOption, skill[:name], category: category)
      end
    end

    def map_experiences!(experiences)
      Array(experiences).each do |experience|
        experience[:technologies] = canonicalize_list(Technology, experience[:technologies])
      end
    end

    def map_educations!(educations)
      Array(educations).each do |education|
        education[:degree]         = canonicalize(Degree, education[:degree])
        education[:field_of_study] = canonicalize(FieldOfStudy, education[:field_of_study])
      end
    end

    def canonicalize_list(model, values)
      Array(values).filter_map { |value| canonicalize(model, value) }
    end

    # Returns the canonical lookup value, creating a `pending` row when missing.
    def canonicalize(model, value, category: nil)
      return value if value.blank?

      option = model.find_or_initialize_by(
        normalized_value: model.normalize_value(value),
        **category_scope(model, category)
      )

      if option.new_record?
        option.assign_attributes(value: value, status: 'pending', submitted_by_user: @user)
        option.save!
        value
      else
        option.value
      end
    end

    def category_scope(model, category)
      return {} unless model.column_names.include?('category')

      { category: (category.presence || SkillOption::CATEGORIES.first).to_s }
    end
  end
end
