# frozen_string_literal: true

describe Resumes::ResumeParser do
  describe '.build' do
    it 'builds the Gemini parser by default' do
      parser = described_class.build(data: 'bytes', media_type: 'application/pdf')

      expect(parser).to be_a(Resumes::GeminiResumeParser)
    end

    it 'builds the provider named by RESUME_PARSER_PROVIDER' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('RESUME_PARSER_PROVIDER', anything).and_return('anthropic')

      parser = described_class.build(data: 'bytes', media_type: 'application/pdf')

      expect(parser).to be_a(Resumes::AnthropicResumeParser)
    end

    it 'honors an explicit provider override (case-insensitive)' do
      parser = described_class.build(data: 'bytes', media_type: 'application/pdf', provider: 'Anthropic')

      expect(parser).to be_a(Resumes::AnthropicResumeParser)
    end

    it 'passes an injected client through to the parser' do
      client = Object.new
      parser = described_class.build(data: 'bytes', media_type: 'application/pdf', provider: 'gemini', client: client)

      expect(parser.instance_variable_get(:@client)).to be(client)
    end

    it 'raises an ImportError for an unknown provider' do
      expect {
        described_class.build(data: 'bytes', media_type: 'application/pdf', provider: 'openai')
      }.to raise_error(Resumes::ImportError, /unknown resume parser provider/i)
    end
  end
end
