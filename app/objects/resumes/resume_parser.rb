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
  # Prompt text lives in Resumes::ResumeParser::Prompt.
  class ResumeParser
    MODEL = 'claude-haiku-4-5'
    MAX_TOKENS = 8_000
    TIMEOUT_SECONDS = 120
    SKILL_CATEGORIES = %w[technical soft tools].freeze
    URL_SCHEME = %r{\Ahttps?://}

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
        system_: [{ type: 'text', text: Prompt::SYSTEM, cache_control: { type: 'ephemeral' } }],
        messages: [{ role: 'user', content: content_blocks }]
      )
    rescue StandardError => e
      raise ImportError, "Resume parsing service error: #{e.message}"
    end

    def content_blocks
      [document_block, { type: 'text', text: Prompt::USER }]
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

    # Normalize whatever the model returned so a partial or slightly-off parse
    # still persists — we only work with the data we actually got. Missing fields
    # stay missing; entries lacking their required field are dropped, and
    # present-but-invalid values are coerced past model validations (NOT NULL
    # jsonb arrays, the `current` flag, URLs without a scheme, out-of-range years,
    # unknown skill categories) rather than failing the whole import.
    def sanitize(parsed)
      sanitize_profile(parsed)
      sanitize_experiences(parsed)
      sanitize_skills(parsed)
      sanitize_educations(parsed)
      sanitize_certifications(parsed)
      sanitize_projects(parsed)
      parsed
    end

    def sanitize_profile(parsed)
      profile = parsed[:profile]
      return unless profile.is_a?(Hash)

      coalesce_profile_lists(profile)
      repair_profile_urls(profile)
      return unless profile.key?(:years_of_experience)

      profile[:years_of_experience] = int_within(profile[:years_of_experience], 0, 60)
    end

    # Profile list fields are NOT NULL jsonb (default []); coalesce an explicit
    # null to []. Absent keys are left untouched (the DB default applies).
    def coalesce_profile_lists(profile)
      %i[languages awards volunteer_experiences interests].each do |key|
        profile[key] = Array(profile[key]) if profile.key?(key)
      end
    end

    def repair_profile_urls(profile)
      %i[linkedin_url github_url portfolio_url].each do |key|
        profile[key] = normalize_url(profile[key]) if profile.key?(key)
      end
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

    def sanitize_skills(parsed)
      parsed[:skills] = Array(parsed[:skills]).filter_map do |skill|
        next if skill[:name].blank?

        category = SKILL_CATEGORIES.include?(skill[:category]) ? skill[:category] : 'technical'
        skill.merge(category: category)
      end
    end

    def sanitize_educations(parsed)
      parsed[:educations] = Array(parsed[:educations]).filter_map do |education|
        next if education[:institution].blank?

        education.merge(
          start_year: int_within(education[:start_year], 1900, 2100),
          end_year: int_within(education[:end_year], 1900, 2100)
        )
      end
    end

    def sanitize_certifications(parsed)
      parsed[:certifications] = Array(parsed[:certifications]).filter_map do |certification|
        next if certification[:name].blank?

        certification.merge(url: normalize_url(certification[:url]))
      end
    end

    def sanitize_projects(parsed)
      parsed[:projects] = Array(parsed[:projects]).filter_map do |project|
        next if project[:title].blank?

        project.merge(url: normalize_url(project[:url]))
      end
    end

    # Repairs a URL the model returned without a scheme (e.g. "linkedin.com/in/x")
    # so it passes the models' http(s):// format validation. Blank -> nil.
    def normalize_url(value)
      url = value.to_s.strip
      return if url.blank?
      return url if url.match?(URL_SCHEME)

      "https://#{url.delete_prefix('//')}"
    end

    # Returns the integer if it falls within [min, max], else nil — so an
    # out-of-range value never trips a numericality validation.
    def int_within(value, min, max)
      int = Integer(value, exception: false)
      return if int.nil? || int < min || int > max

      int
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
