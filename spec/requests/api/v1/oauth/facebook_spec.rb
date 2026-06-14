# frozen_string_literal: true

describe 'POST api/v1/users/oauth/facebook' do
  subject { post '/api/v1/users/oauth/facebook', params:, as: :json }

  let(:app_id) { '1234567890' }
  let(:app_secret) { 'facebook-app-secret' }
  let(:access_token) { 'facebook-user-access-token' }
  let(:params) { { access_token: } }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('FACEBOOK_APP_ID', nil).and_return(app_id)
    allow(ENV).to receive(:fetch).with('FACEBOOK_APP_SECRET', nil).and_return(app_secret)

    stub_request(:get, %r{https://graph\.facebook\.com/v21\.0/debug_token})
      .to_return(
        status: 200,
        body: {
          data: {
            app_id: app_id,
            is_valid: true,
            user_id: '987654321'
          }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    stub_request(:get, %r{https://graph\.facebook\.com/v21\.0/me})
      .to_return(
        status: 200,
        body: {
          id: '987654321',
          email: 'facebook.user@example.com',
          first_name: 'Facebook',
          last_name: 'User',
          name: 'Facebook User'
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  context 'when an email account already exists' do
    let!(:existing_user) do
      create(:user, email: 'facebook.user@example.com', provider: 'email', password: 'password')
    end

    before { subject }

    it 'returns success' do
      expect(response).to be_successful
    end

    it 'links OAuth to the existing user instead of creating a duplicate' do
      expect(User.where(email: 'facebook.user@example.com').count).to eq(1)
      expect(existing_user.reload.provider).to eq('email')
    end

    it 'returns auth headers for the existing user' do
      token = response.header['access-token']
      client = response.header['client']
      expect(existing_user.reload).to be_valid_token(token, client)
    end

    it 'does not require password setup for email accounts' do
      expect(json[:user][:needs_password_setup]).to be(false)
    end
  end

  context 'with a valid access token' do
    before { subject }

    it 'returns success' do
      expect(response).to be_successful
    end

    it 'creates a facebook user' do
      user = User.find_by(provider: 'facebook', uid: '987654321')
      expect(user).to be_present
      expect(user.email).to eq('facebook.user@example.com')
      expect(user.first_name).to eq('Facebook')
      expect(user.last_name).to eq('User')
    end

    it 'returns auth headers' do
      token = response.header['access-token']
      client = response.header['client']
      user = User.find_by(provider: 'facebook', uid: '987654321')
      expect(user).to be_valid_token(token, client)
    end

    it 'returns the user payload' do
      expect(json[:user][:email]).to eq('facebook.user@example.com')
      expect(json[:user][:provider]).to eq('facebook')
      expect(json[:user][:needs_password_setup]).to be(true)
    end
  end

  context 'when the access token is missing' do
    let(:params) { {} }

    before { subject }

    it 'returns unauthorized' do
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns an error message' do
      expect(json[:errors].first[:message]).to eq('Missing Facebook access token')
    end
  end

  context 'when facebook is not configured' do
    before do
      allow(ENV).to receive(:fetch).with('FACEBOOK_APP_ID', nil).and_return(nil)
      allow(ENV).to receive(:fetch).with('FACEBOOK_APP_SECRET', nil).and_return(nil)
      subject
    end

    it 'returns unauthorized' do
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns an error message' do
      expect(json[:errors].first[:message]).to eq('Facebook sign-in is not configured')
    end
  end
end
