# frozen_string_literal: true

# Plain doubles stand in for the third-party Anthropic SDK surface (client,
# messages resource, message + content blocks), which has no stable public
# classes worth verifying against.
# rubocop:disable RSpec/VerifiedDoubles
describe Resumes::ResumeParser do
  let(:text) { '{}' }
  let(:messages) { double('messages') }
  let(:client) { double('client', messages: messages) }
  let(:response) { double('response', content: [double('block', type: :text, text: text)]) }

  before { allow(messages).to receive(:create).and_return(response) }

  def parse(payload)
    allow(response).to receive(:content).and_return([double('block', type: :text, text: payload)])
    described_class.new(data: 'bytes', media_type: 'application/pdf', client: client).call
  end

  it 'parses the model JSON into a symbolized hash' do
    result = parse({ title: 'X', profile: { full_name: 'Ada' } }.to_json)

    expect(result[:title]).to eq('X')
    expect(result.dig(:profile, :full_name)).to eq('Ada')
  end

  it 'strips markdown code fences before parsing' do
    result = parse("```json\n{\"title\":\"Fenced\"}\n```")

    expect(result[:title]).to eq('Fenced')
  end

  it 'fills a missing required experience field and defaults arrays/flags' do
    result = parse({ experiences: [{ job_title: 'Engineer' }] }.to_json)

    experience = result[:experiences].first
    expect(experience[:company]).to eq('Engineer')
    expect(experience[:current]).to be(false)
    expect(experience[:responsibilities]).to eq([])
  end

  it 'drops child records that lack their identifying field' do
    result = parse({ skills: [{ name: 'Ruby', category: 'technical' }, { name: nil }] }.to_json)

    expect(result[:skills].size).to eq(1)
  end

  it 'raises a ParseError on non-JSON output' do
    expect { parse('this is not json') }.to raise_error(Resumes::ImportError, /could not read/i)
  end

  it 'wraps Anthropic client failures in a ParseError' do
    allow(messages).to receive(:create).and_raise(StandardError, 'network down')

    expect {
      described_class.new(data: 'bytes', media_type: 'application/pdf', client: client).call
    }.to raise_error(Resumes::ImportError, /service error/i)
  end
end
# rubocop:enable RSpec/VerifiedDoubles
