# frozen_string_literal: true

describe 'POST api/v1/users/oauth/facebook (token cleanup)' do
  subject { post '/api/v1/users/oauth/facebook', params:, as: :json }

  let(:app_id) { '1234567890' }
  let(:app_secret) { 'facebook-app-secret' }
  let(:access_token) { 'facebook-user-access-token' }
  let(:params) { { access_token: } }
  let!(:user) do
    create(:user, provider: 'facebook', uid: '987654321', email: 'facebook.user@example.com', password: 'password')
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('FACEBOOK_APP_ID', nil).and_return(app_id)
    allow(ENV).to receive(:fetch).with('FACEBOOK_APP_SECRET', nil).and_return(app_secret)

    6.times do |index|
      user.tokens["device#{index}"] = { 'token' => "$2a$10$device#{index}", 'expiry' => 2.years.from_now.to_i }
    end
    user.save!

    stub_request(:get, %r{https://graph\.facebook\.com/v21\.0/debug_token})
      .to_return(
        status: 200,
        body: { data: { app_id: app_id, is_valid: true, user_id: '987654321' } }.to_json,
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

    subject
  end

  it 'returns success' do
    expect(response).to be_successful
  end

  it 'returns a token that validates on the next request' do
    token = response.header['access-token']
    client = response.header['client']
    uid = response.header['uid']

    get '/api/v1/user', headers: { 'access-token' => token, 'client' => client, 'uid' => uid }, as: :json

    expect(response).to be_successful
    expect(json[:user][:email]).to eq('facebook.user@example.com')
  end
end
