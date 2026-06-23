# frozen_string_literal: true

require 'date'
require 'digest'
require 'json'

module Resumes
  # Provider-agnostic resume parser: turns an uploaded resume (PDF or image
  # bytes) into a structured hash shaped exactly like the `PATCH /resumes/:id/draft`
  # params, so the result can be fed straight into Resumes::DraftUpdater.
  #
  # Subclasses implement only the provider-specific bits — #request (the model
  # call) and #extract_text (pull the response's text) — while this base owns the
  # shared shape: JSON parsing, fence stripping, and the extensive sanitization
  # that coerces a partial/slightly-off parse past every model validation.
  #
  # Concrete parsers: Resumes::AnthropicResumeParser, Resumes::GeminiResumeParser.
  # Don't instantiate a provider directly from app code — go through the
  # Resumes::ResumeParser factory so RESUME_PARSER_PROVIDER stays the single switch.
  class BaseResumeParser
    SKILL_CATEGORIES = %w[technical soft tools].freeze
    URL_SCHEME = %r{\Ahttps?://}

    # String length caps mirroring each model's `length: { maximum: }` validation.
    # The model can return arbitrarily long values; truncate rather than let one
    # over-length field roll back the whole (single-transaction) import.
    PROFILE_LENGTHS = {
      full_name: 120, job_title: 120, industry: 120, phone: 40,
      location_city: 80, location_country: 80, career_summary: 1_200
    }.freeze
    EXPERIENCE_LENGTHS = { company: 120, job_title: 120, location: 120 }.freeze
    EDUCATION_LENGTHS = { institution: 160, degree: 160, field_of_study: 160 }.freeze
    SKILL_LENGTHS = { name: 80 }.freeze
    CERTIFICATION_LENGTHS = { name: 160, issuer: 160 }.freeze
    PROJECT_LENGTHS = { title: 160, role: 160, description: 1_500 }.freeze

    # When the model omits an entry's required identifying field but the entry
    # still carries other content, fill the field with a clearly-editable
    # placeholder so the entry persists rather than being dropped. (Skills are
    # exempt: a nameless skill carries nothing to save, so it's still dropped.)
    PLACEHOLDERS = {
      company: 'Unknown company',
      job_title: 'Untitled role',
      institution: 'Unknown institution',
      project_title: 'Untitled project',
      certification_name: 'Untitled certification'
    }.freeze

    # Re-parsing the same bytes always yields the same result, so cache it and skip
    # the (slow, paid) model call on duplicate or retried uploads. Keyed by a digest
    # of the document so no resume content lands in the key; the short TTL bounds
    # how long parsed PII lingers in the cache store. No-op under :null_store (test).
    RESULT_CACHE_NAMESPACE = 'resumes/parse'
    RESULT_CACHE_TTL = 1.hour

    def initialize(data:, media_type:, client: nil)
      @data = data
      @media_type = media_type
      @client = client
    end

    # @return [Hash] symbolized hash matching ResumesController#draft_params
    def call
      Rails.cache.fetch(cache_key, expires_in: RESULT_CACHE_TTL) { parse(request) }
    end

    private

    # Provider + model scope the key so switching providers can't return another
    # model's parse for the same file.
    def cache_key
      model = self.class.const_defined?(:MODEL) ? self.class::MODEL : self.class.name
      fingerprint = Digest::SHA256.hexdigest("#{self.class.name}\0#{model}\0#{@media_type}\0#{@data}")
      "#{RESULT_CACHE_NAMESPACE}/#{fingerprint}"
    end

    # @!method request
    #   Send the document to the provider and return its raw response object.
    #   @abstract
    def request
      raise NotImplementedError, "#{self.class} must implement #request"
    end

    # @!method extract_text(response)
    #   Pull the model's text payload out of the provider's raw response.
    #   @abstract
    def extract_text(_response)
      raise NotImplementedError, "#{self.class} must implement #extract_text"
    end

    def parse(response)
      text = extract_text(response)
      sanitize(JSON.parse(strip_fences(text)).deep_symbolize_keys)
    rescue JSON::ParserError => e
      raise ImportError, "Could not read the resume contents: #{e.message}"
    end

    # Normalize whatever the model returned so a partial or slightly-off parse
    # still persists — we only work with the data we actually got. An entry that
    # lacks its required identifying field but carries other content keeps a
    # PLACEHOLDERS value for it (rather than being dropped), so no uploaded info
    # is lost; only entries with no usable content at all are dropped. Present-
    # but-invalid values are coerced past model validations (NOT NULL jsonb
    # arrays, the `current` flag, schemeless URLs, out-of-range years, unknown
    # skill categories, over-length strings, end-before-start ranges).
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
      clamp_lengths(profile, PROFILE_LENGTHS)
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
      return if blank_entry?(experience)

      normalized = experience.merge(
        **experience_identity(experience),
        current: experience[:current] == true,
        responsibilities: Array(experience[:responsibilities]),
        achievements: Array(experience[:achievements]),
        technologies: Array(experience[:technologies])
      )
      drop_inverted_date(normalized, :start_date, :end_date)
      clamp_lengths(normalized, EXPERIENCE_LENGTHS)
    end

    # Company and job_title are both required; fill each from the other when only
    # one is present, falling back to a placeholder when the model gave neither.
    def experience_identity(experience)
      company = experience[:company].presence
      job_title = experience[:job_title].presence
      {
        company: company || job_title || PLACEHOLDERS[:company],
        job_title: job_title || company || PLACEHOLDERS[:job_title]
      }
    end

    def sanitize_skills(parsed)
      parsed[:skills] = Array(parsed[:skills]).filter_map do |skill|
        next if skill[:name].blank?

        category = SKILL_CATEGORIES.include?(skill[:category]) ? skill[:category] : 'technical'
        clamp_lengths(skill.merge(category: category), SKILL_LENGTHS)
      end
    end

    def sanitize_educations(parsed)
      parsed[:educations] = Array(parsed[:educations]).filter_map { |education| normalize_education(education) }
    end

    def normalize_education(education)
      return if blank_entry?(education)

      normalized = education.merge(
        institution: education[:institution].presence || PLACEHOLDERS[:institution],
        start_year: int_within(education[:start_year], 1900, 2100),
        end_year: int_within(education[:end_year], 1900, 2100)
      )
      drop_inverted_year(normalized)
      clamp_lengths(normalized, EDUCATION_LENGTHS)
    end

    # Clears end_year when it precedes start_year so the entry survives the
    # model's end_year_after_start_year validation.
    def drop_inverted_year(education)
      start_year = education[:start_year]
      end_year = education[:end_year]
      education[:end_year] = nil if start_year && end_year && end_year < start_year
    end

    def sanitize_certifications(parsed)
      parsed[:certifications] = Array(parsed[:certifications]).filter_map do |certification|
        next if blank_entry?(certification)

        normalized = certification.merge(
          name: certification[:name].presence || PLACEHOLDERS[:certification_name],
          url: normalize_url(certification[:url])
        )
        drop_inverted_date(normalized, :issue_date, :expiry_date)
        clamp_lengths(normalized, CERTIFICATION_LENGTHS)
      end
    end

    def sanitize_projects(parsed)
      parsed[:projects] = Array(parsed[:projects]).filter_map do |project|
        next if blank_entry?(project)

        normalized = project.merge(
          title: project[:title].presence || PLACEHOLDERS[:project_title],
          url: normalize_url(project[:url])
        )
        clamp_lengths(normalized, PROJECT_LENGTHS)
      end
    end

    # True when the model returned an entry with no usable content at all (every
    # field blank/empty/false) — those are dropped. Anything with even one present
    # value is kept, and its missing required field filled from PLACEHOLDERS.
    def blank_entry?(entry)
      entry.values.all? { |value| Array(value).all?(&:blank?) }
    end

    # Repairs a URL the model returned without a scheme (e.g. "linkedin.com/in/x")
    # so it passes the models' http(s):// format validation. Blank -> nil.
    def normalize_url(value)
      url = value.to_s.strip
      return if url.blank?
      return url if url.match?(URL_SCHEME)

      "https://#{url.delete_prefix('//')}"
    end

    # Truncates each listed string field to its model's max length, leaving
    # non-string/absent values untouched.
    def clamp_lengths(hash, limits)
      limits.each do |key, max|
        next unless hash[key].is_a?(String) && hash[key].length > max

        hash[key] = hash[key][0, max]
      end
      hash
    end

    # Clears the end field when it precedes the start so a misread date range
    # (end before start) doesn't trip the model's chronology validation. Either
    # value being absent or unparseable leaves the pair alone.
    def drop_inverted_date(hash, start_key, end_key)
      start_date = parse_date(hash[start_key])
      end_date = parse_date(hash[end_key])
      hash[end_key] = nil if start_date && end_date && end_date < start_date
    end

    def parse_date(value)
      return unless value.is_a?(String) && value.present?

      Date.parse(value)
    rescue ArgumentError
      nil
    end

    # Returns the integer if it falls within [min, max], else nil — so an
    # out-of-range value never trips a numericality validation.
    def int_within(value, min, max)
      int = Integer(value, exception: false)
      return if int.nil? || int < min || int > max

      int
    end

    # Defensive: the model is told not to fence, but strip ```json ... ``` if present.
    def strip_fences(text)
      text.to_s.strip.sub(/\A```(?:json)?\s*/i, '').delete_suffix('```').strip
    end
  end
end
