# frozen_string_literal: true

describe 'API::V1::Resumes import' do
  let(:user) { create(:user) }
  let(:parsed) do
    {
      title: 'Jane Doe — Resume',
      profile: {
        full_name: 'Jane Doe',
        job_title: 'react developer',
        industry: 'Software',
        interests: ['Chess'],
        languages: [{ name: 'English', proficiency: 'Native' }]
      },
      skills: [{ name: 'Reactjs', category: 'technical' }],
      experiences: [{
        job_title: 'Engineer', company: 'Acme', current: true,
        responsibilities: ['Built things'], achievements: [], technologies: ['Reactjs']
      }],
      educations: [{ institution: 'MIT', degree: 'BSc', field_of_study: 'CS', start_year: 2014, end_year: 2018 }],
      certifications: [],
      projects: []
    }
  end
  let(:pdf) { fixture_file_upload('sample_resume.pdf', 'application/pdf') }

  # Resume creation defaults to the 'spotlight' template (Resume#assign_default_template).
  before do
    create(:template, slug: 'spotlight', name: 'Spotlight')
    Prosopite.pause
  end

  # Lookup creation issues many small per-value queries by design; pause the
  # N+1 detector as the lookups specs do.
  after { Prosopite.resume }

  def stub_parser(result: parsed)
    allow(Resumes::ResumeParser).to receive(:build)
      .and_return(instance_double(Resumes::GeminiResumeParser, call: result))
  end

  describe 'POST /api/v1/resumes/import' do
    it 'requires authentication' do
      post '/api/v1/resumes/import', params: { file: pdf }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates a pre-filled resume from the uploaded file' do
      stub_parser

      expect {
        post '/api/v1/resumes/import', params: { file: pdf }, headers: auth_headers
      }.to change { user.resumes.count }.by(1)

      expect(response).to have_http_status(:created)

      resume = user.resumes.last
      expect(resume.title).to eq('Jane Doe — Resume')
      expect(resume.profile.full_name).to eq('Jane Doe')
      expect(resume.skills.pluck(:name)).to include('Reactjs')
      expect(resume.experiences.pluck(:company)).to include('Acme')
    end

    it 'imports a sparse resume that only has a name' do
      stub_parser(result: { title: 'Sam', profile: { full_name: 'Sam' },
                            skills: [], experiences: [], educations: [],
                            certifications: [], projects: [] })

      post '/api/v1/resumes/import', params: { file: pdf }, headers: auth_headers

      expect(response).to have_http_status(:created)
      resume = user.resumes.last
      expect(resume.profile.full_name).to eq('Sam')
      expect(resume.skills).to be_empty
      expect(resume.experiences).to be_empty
    end

    it 'maps values to existing approved lookups (canonical casing)' do
      create(:job_title, value: 'React Developer', status: 'approved')
      stub_parser

      post '/api/v1/resumes/import', params: { file: pdf }, headers: auth_headers

      expect(user.resumes.last.profile.job_title).to eq('React Developer')
    end

    it 'creates pending lookup rows for unmatched values' do
      stub_parser

      expect {
        post '/api/v1/resumes/import', params: { file: pdf }, headers: auth_headers
      }.to change { SkillOption.pending.where(value: 'Reactjs').count }.by(1)

      expect(SkillOption.pending.find_by(value: 'Reactjs').submitted_by_user).to eq(user)
    end

    it 'rejects unsupported file types' do
      post '/api/v1/resumes/import',
           params: { file: fixture_file_upload('notes.txt', 'text/plain') },
           headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json[:errors].first[:message]).to match(/Unsupported file type/i)
    end

    it 'returns a friendly error when parsing fails' do
      allow(Resumes::ResumeParser).to receive(:build)
        .and_return(instance_double(Resumes::GeminiResumeParser).tap do |parser|
          allow(parser).to receive(:call).and_raise(Resumes::ImportError, 'Could not read the resume contents.')
        end)

      post '/api/v1/resumes/import', params: { file: pdf }, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json[:errors].first[:message]).to eq('Could not read the resume contents.')
    end
  end
end
