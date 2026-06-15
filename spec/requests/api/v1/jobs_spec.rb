# frozen_string_literal: true

describe 'API::V1::Jobs' do
  let(:user) { create(:user) }

  # Seeding rows fires the url uniqueness-validation SELECT repeatedly; pause the
  # suite's Prosopite N+1 guard for these examples.
  before { Prosopite.pause }
  after { Prosopite.resume }

  describe 'GET /api/v1/jobs' do
    before do
      create(:job, source: 'ethiojobs', title: 'Ruby Engineer', remote: true)
      create(:job, source: 'hahu_jobs', title: 'Accountant', remote: false)
      create(:job, :inactive, source: 'ethiojobs', title: 'Old Role')
    end

    it 'requires authentication' do
      get '/api/v1/jobs'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns active jobs with pagination meta' do
      get '/api/v1/jobs', headers: auth_headers

      expect(response).to have_http_status(:success)
      expect(json[:jobs].size).to eq(2)
      expect(json[:meta]).to include('page' => 1, 'total' => 2)
    end

    it 'filters by source' do
      get '/api/v1/jobs', params: { source: 'hahu_jobs' }, headers: auth_headers

      expect(json[:jobs].pluck('source')).to all(eq('hahu_jobs'))
    end

    it 'filters by remote' do
      get '/api/v1/jobs', params: { remote: 'true' }, headers: auth_headers

      expect(json[:jobs].pluck('title')).to contain_exactly('Ruby Engineer')
    end

    it 'searches by term' do
      get '/api/v1/jobs', params: { q: 'ruby' }, headers: auth_headers

      expect(json[:jobs].pluck('title')).to contain_exactly('Ruby Engineer')
    end
  end

  describe 'GET /api/v1/jobs/:id' do
    let(:job) { create(:job, description: '<p>Great <script>alert(1)</script>role</p>') }

    it 'returns the job with a sanitized description' do
      get "/api/v1/jobs/#{job.id}", headers: auth_headers

      expect(response).to have_http_status(:success)
      expect(json[:id]).to eq(job.id)
      expect(json[:description]).to include('Great')
      expect(json[:description]).not_to include('<script>')
    end
  end

  describe 'GET /api/v1/jobs/filters' do
    before { create(:job, employment_type: 'full_time', category: 'Engineering', location: 'Addis Ababa') }

    it 'returns distinct filter options' do
      get '/api/v1/jobs/filters', headers: auth_headers

      expect(response).to have_http_status(:success)
      expect(json[:sources]).to include('ethiojobs', 'hahu_jobs', 'ethiopian_reporter')
      expect(json[:employment_types]).to include('full_time')
      expect(json[:categories]).to include('Engineering')
    end
  end
end
