# frozen_string_literal: true

require 'base64'
require 'json'

module Resumes
  # Sends an uploaded resume (PDF or image bytes) to Anthropic and returns a
  # structured hash shaped exactly like the `PATCH /resumes/:id/draft` params,
  # so the result can be fed straight into Resumes::DraftUpdater.
  #
  # Uses claude-haiku-4-5 — the cheapest model that supports document/vision
  # input — per the onboarding spec's "most cost-effective model" requirement.
  class ResumeParser
    MODEL = 'claude-haiku-4-5'
    MAX_TOKENS = 8_000
    TIMEOUT_SECONDS = 120

    PROMPT = <<~PROMPT
      You are a resume parser. Read the attached resume document and extract its
      contents into a single JSON object with EXACTLY this shape (use null or []
      for anything not present — never invent data):

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
      - Experience and certification dates must be ISO "YYYY-MM-DD" or null.
      - Project, award and volunteer dates may stay as plain text.
      - "years_of_experience" must be an integer between 0 and 60, or null.
      - URLs must be absolute (start with http:// or https://) or null.
    PROMPT

    def initialize(data:, media_type:, client: nil)
      @data = data
      @media_type = media_type
      @client = client
    end

    # @return [Hash] symbolized hash matching ResumesController#draft_params
    def call
      response = request
      parse(response)
    end

    private

    def request
      client.messages.create( # rubocop:disable Rails/SaveBang -- Anthropic SDK call, not ActiveRecord
        model: MODEL,
        max_tokens: MAX_TOKENS,
        messages: [{ role: 'user', content: content_blocks }]
      )
    rescue StandardError => e
      raise ImportError, "Resume parsing service error: #{e.message}"
    end

    def content_blocks
      [document_block, { type: 'text', text: PROMPT }]
    end

    def document_block
      encoded = Base64.strict_encode64(@data)
      source = { type: 'base64', media_type: @media_type, data: encoded }

      if @media_type == 'application/pdf'
        { type: 'document', source: source }
      else
        { type: 'image', source: source }
      end
    end

    def parse(response)
      text = extract_text(response)
      sanitize(JSON.parse(strip_fences(text)).deep_symbolize_keys)
    rescue JSON::ParserError => e
      raise ImportError, "Could not read the resume contents: #{e.message}"
    end

    # Guards against common LLM omissions so persisting via DraftUpdater never
    # trips a NOT NULL constraint: required jsonb arrays default to [], the
    # `current` flag to a boolean, and child records missing every identifying
    # field are dropped (a NOT NULL string column can't be satisfied otherwise).
    def sanitize(parsed)
      sanitize_experiences(parsed)
      sanitize_collection(parsed, :skills, :name)
      sanitize_collection(parsed, :educations, :institution)
      sanitize_collection(parsed, :certifications, :name)
      sanitize_collection(parsed, :projects, :title)
      parsed
    end

    def sanitize_experiences(parsed)
      parsed[:experiences] = Array(parsed[:experiences]).filter_map { |experience| normalize_experience(experience) }
    end

    def normalize_experience(experience)
      company = experience[:company].presence
      job_title = experience[:job_title].presence
      return if company.nil? && job_title.nil?

      experience.merge(
        company: company || job_title,
        job_title: job_title || company,
        current: experience[:current] == true,
        responsibilities: Array(experience[:responsibilities]),
        achievements: Array(experience[:achievements]),
        technologies: Array(experience[:technologies])
      )
    end

    def sanitize_collection(parsed, key, required_field)
      parsed[key] = Array(parsed[key]).select { |item| item[required_field].present? }
    end

    def extract_text(response)
      block = response.content.find { |item| item.type.to_s == 'text' }
      raise ImportError, 'The parser returned no readable content.' if block.nil?

      block.text
    end

    # Defensive: the model is told not to fence, but strip ```json ... ``` if present.
    def strip_fences(text)
      text.to_s.strip.sub(/\A```(?:json)?\s*/i, '').delete_suffix('```').strip
    end

    def client
      @client ||= Anthropic::Client.new(api_key: ENV.fetch('ANTHROPIC_API_KEY'), timeout: TIMEOUT_SECONDS)
    end
  end
end
