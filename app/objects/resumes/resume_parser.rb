# frozen_string_literal: true

module Resumes
  # Factory that picks the resume-parsing provider. RESUME_PARSER_PROVIDER is the
  # single switch (default "gemini" — the cheapest path, gemini-2.5-flash-lite);
  # set it to "anthropic" to fall back to claude-haiku-4-5.
  #
  # Callers use Resumes::ResumeParser.build(data:, media_type:).call and get a
  # hash shaped like ResumesController#draft_params, regardless of provider.
  #
  # Shared prompt text lives under this namespace in Resumes::ResumeParser::Prompt.
  module ResumeParser
    PROVIDERS = {
      'anthropic' => AnthropicResumeParser,
      'gemini' => GeminiResumeParser
    }.freeze
    DEFAULT_PROVIDER = 'gemini'

    module_function

    # @param provider [String, nil] override; defaults to RESUME_PARSER_PROVIDER
    # @param client [Object, nil] injected provider client (tests)
    # @return [BaseResumeParser] a concrete parser instance
    def build(data:, media_type:, provider: nil, client: nil)
      name = (provider || ENV.fetch('RESUME_PARSER_PROVIDER', DEFAULT_PROVIDER)).to_s.downcase
      klass = PROVIDERS.fetch(name) do
        known = PROVIDERS.keys.join(', ')
        raise ImportError, "Unknown resume parser provider: #{name.inspect} (expected one of #{known})"
      end
      klass.new(data: data, media_type: media_type, client: client)
    end
  end
end
