# frozen_string_literal: true

module JobAlerts
  # Scores a single (alert, job) pair and decides whether it is a match.
  #
  # Two kinds of criteria:
  #   * Hard filters (employment type, remote preference, salary floor) — if the
  #     alert specifies one and the job conflicts, it is rejected outright.
  #   * Soft signals (title, keywords, location, experience) — each contributes a
  #     0..1 sub-score; the weighted average over the *specified* signals must clear
  #     THRESHOLD. Unspecified signals are wildcards and don't dilute the score.
  class Matcher
    THRESHOLD = 0.45

    WEIGHTS = { title: 0.40, keywords: 0.30, location: 0.20, experience: 0.10 }.freeze

    STOPWORDS = %w[a an and or the of for to in with at on job role position senior junior].freeze

    Result = Data.define(:matched, :score, :reasons) do
      def matched? = matched
    end

    def self.call(...) = new(...).call

    def initialize(alert, job)
      @alert = alert
      @job = job
    end

    def call
      return Result.new(matched: false, score: 0.0, reasons: ['hard_filter']) unless hard_filters_pass?

      signals = scoring_signals
      return Result.new(matched: true, score: 1.0, reasons: ['filters_only']) if signals.empty?

      total_weight = signals.keys.sum { |key| WEIGHTS[key] }
      score = signals.sum { |key, value| value * WEIGHTS[key] } / total_weight
      reasons = signals.select { |_key, value| value.positive? }.keys.map(&:to_s)
      Result.new(matched: score >= THRESHOLD, score: score.round(3), reasons:)
    end

    private

    attr_reader :alert, :job

    # ---- hard filters -------------------------------------------------------

    def hard_filters_pass?
      employment_ok? && remote_ok? && salary_ok?
    end

    def employment_ok?
      return true if alert.employment_types.blank?

      alert.employment_types.map(&:to_s).include?(job.employment_type.to_s)
    end

    def remote_ok?
      case alert.remote_preference
      when 'remote' then job.remote?
      when 'on_site' then !job.remote?
      else true # any / hybrid
      end
    end

    def salary_ok?
      return true if alert.salary_min.blank?

      value = job_salary_value
      value.nil? || value >= alert.salary_min # unknown salary never excludes
    end

    # Prefer the enriched numeric salary; fall back to parsing the raw string.
    def job_salary_value
      job.salary_max || job.salary_min || parse_salary(job.salary)
    end

    # ---- soft signals -------------------------------------------------------

    def scoring_signals
      signals = {}
      signals[:title] = title_score if alert.titles.present?
      signals[:keywords] = keyword_score if alert.keywords.present?
      signals[:location] = location_score if alert.locations.present?
      signals[:experience] = experience_score if alert.experience_levels.present?
      signals
    end

    def title_score
      job_tokens = tokens(job.title)
      return 0.0 if job_tokens.empty?

      alert.titles.map { |title| overlap(tokens(title), job_tokens) }.max.to_f
    end

    def keyword_score
      found = alert.keywords.count { |keyword| haystack.include?(keyword.to_s.downcase.strip) }
      found.to_f / alert.keywords.size
    end

    def location_score
      return 1.0 if job.remote? && alert.remote_preference != 'on_site'

      location_haystack = [job.location, job.region].compact.join(' ').downcase
      alert.locations.any? { |loc| location_haystack.include?(loc.to_s.downcase.strip) } ? 1.0 : 0.0
    end

    def experience_score
      job_level = [job.experience_level, job.seniority].compact.join(' ').downcase.strip
      return 0.5 if job_level.blank? # neutral when the job omits it

      matched = alert.experience_levels.any? do |level|
        needle = level.to_s.downcase.strip
        needle.present? && (job_level.include?(needle) || needle.include?(job_level))
      end
      matched ? 1.0 : 0.0
    end

    # ---- helpers ------------------------------------------------------------

    def haystack
      @haystack ||= [
        job.title, job.summary, job.ai_summary, job.description, job.company_name,
        job.category, job.seniority,
        Array(job.tags).join(' '), Array(job.skills).join(' '),
        Array(job.preferred_skills).join(' '), Array(job.responsibilities).join(' '),
        Array(job.qualifications).join(' '), Array(job.benefits).join(' ')
      ].compact.join(' ').downcase
    end

    def overlap(needle_tokens, job_tokens)
      return 0.0 if needle_tokens.empty?

      matched = needle_tokens.count { |word| job_tokens.include?(word) }
      matched.to_f / needle_tokens.size
    end

    def tokens(string)
      string.to_s.downcase.scan(/[a-z0-9]+/) - STOPWORDS
    end

    def parse_salary(raw)
      return if raw.blank?

      numbers = raw.to_s.delete(',').scan(/\d+/).map(&:to_i)
      numbers.max
    end
  end
end
