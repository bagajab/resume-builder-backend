# frozen_string_literal: true

# Plain doubles stand in for the third-party Anthropic SDK surface (client,
# messages resource, message + content blocks), which has no stable public
# classes worth verifying against. The provider-agnostic sanitization under test
# here lives in Resumes::BaseResumeParser; this exercises it through the Anthropic
# subclass (Resumes::GeminiResumeParser has its own spec).
# rubocop:disable RSpec/VerifiedDoubles
describe Resumes::AnthropicResumeParser do
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

  it 'drops a nameless skill (a skill with no name carries nothing to keep)' do
    result = parse({ skills: [{ name: 'Ruby', category: 'technical' }, { name: nil }] }.to_json)

    expect(result[:skills].size).to eq(1)
  end

  it 'keeps experience/education/project/certification entries missing their required field, with a placeholder' do
    result = parse({
      experiences: [{ responsibilities: ['Led the team'], start_date: '2020-01-01' }],
      educations: [{ degree: 'BSc', start_year: 2018 }],
      projects: [{ description: 'A side project', url: 'github.com/sam/x' }],
      certifications: [{ issuer: 'Amazon', issue_date: '2021-06-01' }]
    }.to_json)

    expect(result[:experiences].first).to include(company: 'Unknown company', job_title: 'Untitled role')
    expect(result[:experiences].first[:responsibilities]).to eq(['Led the team'])
    expect(result[:educations].first).to include(institution: 'Unknown institution', degree: 'BSc')
    expect(result[:projects].first).to include(title: 'Untitled project', url: 'https://github.com/sam/x')
    expect(result[:certifications].first).to include(name: 'Untitled certification', issuer: 'Amazon')
  end

  it 'drops entries that carry no usable content at all' do
    result = parse({
      experiences: [{ company: nil, job_title: '', responsibilities: [] }],
      educations: [{ institution: nil, degree: '' }],
      projects: [{ title: nil, description: nil }],
      certifications: [{ name: nil, issuer: '' }]
    }.to_json)

    expect(result[:experiences]).to be_empty
    expect(result[:educations]).to be_empty
    expect(result[:projects]).to be_empty
    expect(result[:certifications]).to be_empty
  end

  it 'keeps a sparse resume valid (null profile lists become [])' do
    result = parse({ profile: { full_name: 'Sam', languages: nil, interests: nil } }.to_json)

    expect(result.dig(:profile, :full_name)).to eq('Sam')
    expect(result.dig(:profile, :languages)).to eq([])
    expect(result.dig(:profile, :interests)).to eq([])
  end

  it 'coerces present-but-invalid values past model validations' do
    result = parse({
      profile: { linkedin_url: 'linkedin.com/in/sam', years_of_experience: 999 },
      skills: [{ name: 'Go', category: 'programming' }],
      educations: [{ institution: 'MIT', start_year: 20 }],
      projects: [{ title: 'Site', url: 'github.com/sam/site' }]
    }.to_json)

    expect(result.dig(:profile, :linkedin_url)).to eq('https://linkedin.com/in/sam')
    expect(result.dig(:profile, :years_of_experience)).to be_nil
    expect(result[:skills].first[:category]).to eq('technical')
    expect(result[:educations].first[:start_year]).to be_nil
    expect(result[:projects].first[:url]).to eq('https://github.com/sam/site')
  end

  it 'truncates over-length strings to the model length caps' do
    result = parse({
      profile: { full_name: 'a' * 200 },
      experiences: [{ company: 'b' * 200, job_title: 'Engineer' }],
      projects: [{ title: 'Site', description: 'c' * 2_000 }]
    }.to_json)

    expect(result.dig(:profile, :full_name).length).to eq(120)
    expect(result[:experiences].first[:company].length).to eq(120)
    expect(result[:projects].first[:description].length).to eq(1_500)
  end

  it 'clears an end date/year that precedes its start so chronology validations pass' do
    result = parse({
      experiences: [{ job_title: 'Engineer', start_date: '2020-01-01', end_date: '2018-01-01' }],
      educations: [{ institution: 'MIT', start_year: 2020, end_year: 2018 }],
      certifications: [{ name: 'AWS', issue_date: '2021-06-01', expiry_date: '2019-06-01' }]
    }.to_json)

    expect(result[:experiences].first[:end_date]).to be_nil
    expect(result[:educations].first[:end_year]).to be_nil
    expect(result[:certifications].first[:expiry_date]).to be_nil
  end

  it 'keeps a valid end date/year untouched' do
    result = parse({
      experiences: [{ job_title: 'Engineer', start_date: '2018-01-01', end_date: '2020-01-01' }],
      educations: [{ institution: 'MIT', start_year: 2018, end_year: 2020 }]
    }.to_json)

    expect(result[:experiences].first[:end_date]).to eq('2020-01-01')
    expect(result[:educations].first[:end_year]).to eq(2020)
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
