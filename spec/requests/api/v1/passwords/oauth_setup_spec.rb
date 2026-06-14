# frozen_string_literal: true

describe 'PUT api/v1/users/password (OAuth password setup)' do
  let(:user) do
    create(
      :user,
      provider: 'google_oauth2',
      uid: 'google-sub-id',
      password: 'random-oauth-password',
      password_set: false,
      allow_password_change: true
    )
  end
  let(:headers) { user.create_new_auth_token }
  let(:new_password) { 'newpassword123' }
  let(:params) do
    {
      password: new_password,
      password_confirmation: new_password
    }
  end

  before do
    put user_password_path, params:, headers:, as: :json
  end

  it 'returns success' do
    expect(response).to have_http_status(:success)
  end

  it 'marks the password as set' do
    expect(user.reload.password_set).to be(true)
    expect(user.allow_password_change).to be(false)
  end

  it 'allows signing in with email and password' do
    post '/api/v1/users/sign_in',
         params: { user: { email: user.email, password: new_password } },
         as: :json

    expect(response).to be_successful
  end
end
