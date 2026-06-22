# frozen_string_literal: true

describe 'API::V1::Lookups' do
  let(:user) { create(:user) }

  before { Prosopite.pause }
  after { Prosopite.resume }

  describe 'GET /api/v1/lookups/:list' do
    before do
      create(:country, value: 'Ethiopia')
      create(:country, value: 'Kenya')
      create(:country, value: 'Eritrea', status: 'pending')
    end

    it 'requires authentication' do
      get '/api/v1/lookups/country'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns only approved options' do
      get '/api/v1/lookups/country', headers: auth_headers

      expect(response).to have_http_status(:success)
      expect(json[:options].pluck('value')).to contain_exactly('Ethiopia', 'Kenya')
    end

    it 'searches by relevance' do
      get '/api/v1/lookups/country', params: { q: 'eth' }, headers: auth_headers

      values = json[:options].pluck('value')
      expect(values).to include('Ethiopia')
      expect(values).not_to include('Kenya')
    end

    it "surfaces the requesting user's own pending submissions" do
      create(:country, value: 'Djibouti', status: 'pending', submitted_by_user: user)

      get '/api/v1/lookups/country', headers: auth_headers

      expect(json[:options].pluck('value')).to include('Djibouti')
    end

    it "hides other users' pending submissions" do
      create(:country, value: 'Somalia', status: 'pending', submitted_by_user: create(:user))

      get '/api/v1/lookups/country', headers: auth_headers

      expect(json[:options].pluck('value')).not_to include('Somalia')
    end

    it 'returns 404 for an unknown list' do
      get '/api/v1/lookups/nonsense', headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'filters skills by category' do
      create(:skill_option, value: 'React', category: 'technical')
      create(:skill_option, value: 'Leadership', category: 'soft')

      get '/api/v1/lookups/skill', params: { category: 'soft' }, headers: auth_headers

      expect(json[:options].pluck('value')).to contain_exactly('Leadership')
    end
  end

  describe 'POST /api/v1/lookups/:list' do
    it 'requires authentication' do
      post '/api/v1/lookups/city', params: { value: 'Mekelle' }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates a pending option attributed to the user' do
      expect {
        post '/api/v1/lookups/city', params: { value: 'Mekelle' }, headers: auth_headers, as: :json
      }.to change(City, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json[:status]).to eq('pending')
      expect(City.last.submitted_by_user).to eq(user)
    end

    it 'is idempotent and case/whitespace-insensitive' do
      create(:city, value: 'Mekelle', status: 'approved')

      expect {
        post '/api/v1/lookups/city', params: { value: '  mekelle ' }, headers: auth_headers, as: :json
      }.not_to change(City, :count)

      expect(response).to have_http_status(:ok)
      expect(json[:status]).to eq('approved')
    end

    it 'requires a value' do
      post '/api/v1/lookups/city', params: {}, headers: auth_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'creates a skill within a category' do
      post '/api/v1/lookups/skill', params: { value: 'Rust', category: 'technical' }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(SkillOption.last).to have_attributes(value: 'Rust', category: 'technical', status: 'pending')
    end
  end
end
