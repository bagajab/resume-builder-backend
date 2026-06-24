# frozen_string_literal: true

module Jobs
  module Ai
    # Prompt text for job enrichment. SYSTEM is a stable instruction + output
    # schema (it embeds the controlled vocabularies from the Job model so the model
    # can only return canonical values); the per-job source content goes in the
    # user turn. Kept out of Jobs::Enricher so the orchestration stays readable.
    module Prompt
      # Built once from the Job constants so the schema and the validations can
      # never drift apart.
      SYSTEM = <<~PROMPT.freeze
        You normalize raw job postings from Ethiopian job boards into a single
        structured JSON object with EXACTLY the shape below. Use ONLY information
        present in the posting — postings are often incomplete, which is fine. Use
        null for any absent scalar and [] for any list with no entries. Never guess,
        infer, or fabricate facts. Do not copy boilerplate (site nav, ads, equal-
        opportunity statements) into any field.

        {
          "summary": string,                 // 2-4 plain sentences a job seeker can skim; no fluff
          "clean_description": string,       // the full description as clean plain text / light markdown, boilerplate removed
          "category": string,                // EXACTLY one of the allowed categories below (closest match; "Other" if none fit)
          "employment_type": string|null,    // one of: #{Job::EMPLOYMENT_TYPES.join(', ')}
          "seniority": string|null,          // one of: #{Job::SENIORITY_LEVELS.join(', ')}
          "experience_years_min": integer|null,  // minimum years required, 0..60
          "education_level": string|null,    // normalized, e.g. "Bachelor's Degree", "Diploma", "Master's Degree"
          "remote_type": string|null,        // one of: #{Job::REMOTE_TYPES.join(', ')}
          "salary_min": integer|null,        // numeric amount only, no separators
          "salary_max": integer|null,
          "salary_currency": string|null,    // ISO-style code, e.g. "ETB", "USD"
          "salary_period": string|null,      // one of: #{Job::SALARY_PERIODS.join(', ')}
          "skills": [string],                // required/hard skills, short noun phrases, de-duplicated
          "preferred_skills": [string],      // nice-to-have skills
          "languages": [string],             // spoken/written languages required, e.g. "English", "Amharic"
          "benefits": [string],              // perks: insurance, transport allowance, etc.
          "responsibilities": [string],      // key duties, one per item
          "qualifications": [string],        // required qualifications/requirements, one per item
          "application_instructions": string|null  // how to apply, condensed
        }

        Allowed categories (use the value verbatim):
        #{Job::CATEGORIES.map { |c| "  - #{c}" }.join("\n")}

        Rules:
        - Respond with ONLY the JSON object. No prose, no markdown fences.
        - "category" is REQUIRED and MUST be one of the allowed categories exactly.
        - Enum fields must use one of their listed lowercase values, or null.
        - Salary numbers must be plain integers (strip commas/currency words); set
          salary_currency/salary_period when stated. If only one figure is given,
          put it in salary_min and leave salary_max null.
        - Keep list items concise; do not duplicate an entry across skills and
          preferred_skills.
      PROMPT

      module_function

      # @param content [String] boilerplate-stripped source content
      # @param category_hint [String, nil] the source-provided category, if any
      def user(content, category_hint: nil)
        hint = category_hint.present? ? "Source category hint (may be wrong): #{category_hint}\n\n" : ''
        "#{hint}Normalize this job posting into the JSON object defined in your " \
          "instructions. Return only the JSON.\n\n---\n#{content}"
      end
    end
  end
end
