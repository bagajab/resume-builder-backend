# frozen_string_literal: true

module Resumes
  # Writes a concise professional summary for a résumé from its own profile,
  # experience, skills and education using the shared Gemini client. Returns a
  # plain string (a few sentences, résumé prose). Raises
  # SummaryGenerator::Error when the model is unavailable or returns nothing, so
  # the controller can surface a clean "try again later" rather than a 500.
  class SummaryGenerator
    class Error < StandardError; end

    MAX_OUTPUT_TOKENS = 400

    SYSTEM = <<~PROMPT
      You are a professional résumé writer. Using only the candidate JSON the
      user provides, write a polished professional summary for the top of their
      résumé. Rules:
      - 2 to 4 sentences, roughly 40-90 words.
      - Résumé prose in the third-person-implied style (no "I"/"my"), e.g.
        "Senior product designer with 6 years...".
      - Lead with their role and years of experience, then their strongest
        skills and the domains/industries they work in.
      - No headings, markdown, bullet points, quotes or placeholders. Plain prose.
      - Never invent facts that are not supported by the JSON.
      Respond with a JSON object of the exact shape: {"career_summary": "..."}.
    PROMPT

    def initialize(resume, client: nil)
      @resume = resume
      @client = client
    end

    def call
      raise Error, 'AI summary generation is not configured' unless client

      result = client.generate_json(
        system: SYSTEM,
        user: candidate_json,
        max_output_tokens: MAX_OUTPUT_TOKENS
      )
      summary = result['career_summary'].to_s.strip
      raise Error, 'The model returned an empty summary' if summary.blank?

      summary
    rescue Jobs::Ai::GeminiClient::Error => e
      raise Error, e.message
    end

    private

    attr_reader :resume

    def client
      @client ||= (Jobs::Ai::GeminiClient.new if Jobs::Ai::GeminiClient.configured?)
    end

    def candidate_json
      profile = resume.profile
      {
        name: profile&.full_name,
        job_title: profile&.job_title,
        years_of_experience: profile&.years_of_experience,
        industry: profile&.industry,
        existing_summary: profile&.career_summary.presence,
        experiences: resume.experiences.first(6).map do |exp|
          {
            title: exp.job_title,
            company: exp.company,
            highlights: Array(exp.responsibilities).reject(&:blank?).first(3)
          }
        end,
        skills: resume.skills.map(&:name).reject(&:blank?).first(15),
        educations: resume.educations.first(4).map do |edu|
          { degree: edu.degree, field: edu.field_of_study, institution: edu.institution }
        end
      }.to_json
    end
  end
end
