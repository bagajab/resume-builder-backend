# frozen_string_literal: true

module Resumes
  module ResumeParser
    # Prompt text shared by every resume-parsing provider, kept out of the service
    # classes so the logic stays readable.
    #
    # SYSTEM holds the stable instructions + schema, so it forms a cacheable
    # prefix (caching is a prefix match: tools -> system -> messages); the
    # per-resume document goes in the user turn, after the cache breakpoint.
    #
    # NOTE: Anthropic only caches a prefix once it reaches the model's minimum
    # (4096 tokens for claude-haiku-4-5). These instructions are well under that,
    # so caching is currently a no-op on Haiku — wired correctly, but it only
    # starts saving once the prompt grows past the threshold or the model changes.
    # The per-request document is unique, so it can't be cached either.
    module Prompt
      SYSTEM = <<~PROMPT
        You are a resume parser. Read the attached resume document and extract ONLY
        the information that actually appears in it into a single JSON object with
        EXACTLY this shape. Resumes are frequently incomplete — that is expected and
        fine. Use null for any absent field and [] for any list with no entries.
        Never guess, infer, or fabricate data to fill the shape.

        {
          "title": string,                      // e.g. "Jane Doe — Resume"
          "profile": {
            "full_name": string|null,
            "phone": string|null,
            "location_city": string|null,
            "location_country": string|null,
            "linkedin_url": string|null,        // full https:// URL or null
            "github_url": string|null,
            "portfolio_url": string|null,
            "job_title": string|null,           // current/most-recent title
            "years_of_experience": integer|null, // 0..60
            "industry": string|null,
            "career_summary": string|null,
            "languages": [{ "name": string, "proficiency": string|null }],
            "awards": [{ "title": string, "organization": string|null, "date": string|null }],
            "volunteer_experiences": [{ "role": string, "organization": string|null, "description": string|null, "date": string|null }],
            "interests": [string]
          },
          "experiences": [{
            "job_title": string|null,
            "company": string|null,
            "location": string|null,
            "start_date": string|null,          // ISO "YYYY-MM-DD" (use -01 for an unknown day) or null
            "end_date": string|null,            // ISO "YYYY-MM-DD" or null if current
            "current": boolean,
            "responsibilities": [string],
            "achievements": [string],
            "technologies": [string]
          }],
          "educations": [{
            "institution": string|null,
            "degree": string|null,
            "field_of_study": string|null,
            "start_year": integer|null,
            "end_year": integer|null,
            "gpa": string|null,
            "honors": string|null
          }],
          "certifications": [{
            "name": string|null,
            "issuer": string|null,
            "issue_date": string|null,          // ISO "YYYY-MM-DD" or null
            "expiry_date": string|null,         // ISO "YYYY-MM-DD" or null
            "url": string|null
          }],
          "skills": [{
            "name": string,
            "category": "technical"|"soft"|"tools" // best guess; default "technical"
          }],
          "projects": [{
            "title": string|null,
            "description": string|null,
            "url": string|null,
            "date": string|null,
            "role": string|null
          }]
        }

        Rules:
        - Respond with ONLY the JSON object. No prose, no markdown fences.
        - Only include entries that genuinely appear in the document. Leave optional
          fields null and absent sections [] rather than padding them with guesses.
        - Experience and certification dates must be ISO "YYYY-MM-DD" or null.
        - Project, award and volunteer dates may stay as plain text.
        - "years_of_experience" must be an integer between 0 and 60, or null.
        - URLs must be absolute (start with http:// or https://) or null.
      PROMPT

      USER = 'Extract this resume into the JSON object defined in your instructions. Return only the JSON.'
    end
  end
end
