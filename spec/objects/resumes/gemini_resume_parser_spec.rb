# frozen_string_literal: true

# A plain double stands in for the gemini-ai client, whose #generate_content
# returns the Generative Language API's string-keyed response hash. Sanitization
# is covered against the Anthropic subclass; this focuses on the Gemini-specific
# request payload, response extraction, and error wrapping.
# rubocop:disable RSpec/VerifiedDoubles
describe Resumes::GeminiResumeParser do
  let(:client) { double('gemini client') }

  def response_with(text)
    { 'candidates' => [{ 'content' => { 'parts' => [{ 'text' => text }] } }] }
  end

  def parse(text)
    allow(client).to receive(:generate_content).and_return(response_with(text))
    described_class.new(data: 'bytes', media_type: 'application/pdf', client: client).call
  end

  it 'parses the Generative Language API response into a symbolized hash' do
    result = parse({ title: 'X', profile: { full_name: 'Ada' } }.to_json)

    expect(result[:title]).to eq('X')
    expect(result.dig(:profile, :full_name)).to eq('Ada')
  end

  it 'concatenates multiple text parts of the first candidate' do
    allow(client).to receive(:generate_content).and_return(
      { 'candidates' => [{ 'content' => { 'parts' => [{ 'text' => '{"title":' }, { 'text' => '"Split"}' }] } }] }
    )

    result = described_class.new(data: 'bytes', media_type: 'application/pdf', client: client).call

    expect(result[:title]).to eq('Split')
  end

  it 'sends the document inline as base64 with a cost-minimized JSON-only generation config' do
    allow(client).to receive(:generate_content).and_return(response_with('{}'))

    described_class.new(data: 'bytes', media_type: 'application/pdf', client: client).call

    expect(client).to have_received(:generate_content).with(
      a_hash_including(
        contents: a_hash_including(
          parts: a_collection_including(
            a_hash_including(inline_data: a_hash_including(mime_type: 'application/pdf'))
          )
        ),
        generation_config: a_hash_including(
          response_mime_type: 'application/json',
          temperature: 0,
          thinking_config: { thinking_budget: 0 }
        )
      ),
      server_sent_events: false
    )
  end

  it 'inherits the shared sanitization (schemeless URLs, array coalescing)' do
    result = parse({ profile: { linkedin_url: 'linkedin.com/in/sam', languages: nil } }.to_json)

    expect(result.dig(:profile, :linkedin_url)).to eq('https://linkedin.com/in/sam')
    expect(result.dig(:profile, :languages)).to eq([])
  end

  it 'raises an ImportError when the response carries no text' do
    allow(client).to receive(:generate_content).and_return({ 'candidates' => [] })

    expect {
      described_class.new(data: 'bytes', media_type: 'application/pdf', client: client).call
    }.to raise_error(Resumes::ImportError, /no readable content/i)
  end

  it 'raises an ImportError on non-JSON output' do
    expect { parse('this is not json') }.to raise_error(Resumes::ImportError, /could not read/i)
  end

  it 'wraps Gemini client failures in an ImportError' do
    allow(client).to receive(:generate_content).and_raise(StandardError, 'network down')

    expect {
      described_class.new(data: 'bytes', media_type: 'application/pdf', client: client).call
    }.to raise_error(Resumes::ImportError, /service error/i)
  end

  # Gemini emits these constantly under load; the importer must not fail the
  # user's upload over a blip the gem itself won't retry.
  describe 'transient-failure retries' do
    def request_error(status)
      faraday = Faraday::ServerError.new('boom', { status: status })
      Gemini::Errors::RequestError.new("status #{status}", request: faraday)
    end

    def parser
      described_class.new(data: 'bytes', media_type: 'application/pdf', client: client).tap do |instance|
        allow(instance).to receive(:sleep) # don't actually back off in tests
      end
    end

    it 'retries a transient 503 and then succeeds' do
      calls = 0
      allow(client).to receive(:generate_content) do
        calls += 1
        raise request_error(503) if calls == 1

        response_with({ title: 'Recovered' }.to_json)
      end

      expect(parser.call[:title]).to eq('Recovered')
      expect(calls).to eq(2)
    end

    it 'gives up after MAX_ATTEMPTS of persistent transience' do
      allow(client).to receive(:generate_content).and_raise(request_error(503))

      expect { parser.call }.to raise_error(Resumes::ImportError, /service error/i)
      expect(client).to have_received(:generate_content).exactly(described_class::MAX_ATTEMPTS).times
    end

    it 'does not retry a non-transient 400' do
      bad = Gemini::Errors::RequestError.new('bad request', request: Faraday::ClientError.new('bad', { status: 400 }))
      allow(client).to receive(:generate_content).and_raise(bad)

      expect { parser.call }.to raise_error(Resumes::ImportError, /service error/i)
      expect(client).to have_received(:generate_content).once
    end
  end

  # The test env uses :null_store, so swap in a real store to exercise caching.
  describe 'result caching' do
    before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

    def parse_once(data)
      described_class.new(data: data, media_type: 'application/pdf', client: client).call
    end

    it 'reuses the cached parse for identical bytes, skipping the model call' do
      allow(client).to receive(:generate_content).and_return(response_with({ title: 'Cached' }.to_json))

      expect(parse_once('same-bytes')[:title]).to eq('Cached')
      expect(parse_once('same-bytes')[:title]).to eq('Cached')

      expect(client).to have_received(:generate_content).once
    end

    it 'calls the model again for different bytes' do
      allow(client).to receive(:generate_content).and_return(response_with('{}'))

      parse_once('resume-a')
      parse_once('resume-b')

      expect(client).to have_received(:generate_content).twice
    end

    it 'does not cache a failed parse' do
      call_count = 0
      allow(client).to receive(:generate_content) do
        call_count += 1
        raise Gemini::Errors::RequestError.new('400', request: Faraday::ClientError.new('bad', { status: 400 }))
      end

      2.times { expect { parse_once('same-bytes') }.to raise_error(Resumes::ImportError) }
      expect(call_count).to eq(2)
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
