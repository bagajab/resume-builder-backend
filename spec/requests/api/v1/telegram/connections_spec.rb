# frozen_string_literal: true

describe 'API::V1::Telegram::Connections' do
  let(:user) { create(:user) }

  before do
    Flipper.enable(:job_alerts)
    Prosopite.pause
  end

  after { Prosopite.resume }

  describe 'GET /api/v1/telegram/connection' do
    it 'reports an unlinked connection' do
      get '/api/v1/telegram/connection', headers: auth_headers
      expect(response).to have_http_status(:success)
      expect(json[:connected]).to be(false)
    end

    it 'reports a linked connection' do
      create(:telegram_connection, :linked, user:)
      get '/api/v1/telegram/connection', headers: auth_headers
      expect(json[:connected]).to be(true)
      expect(json[:phone_number]).to eq('+251911223344')
    end
  end

  describe 'POST /api/v1/telegram/connection' do
    it 'issues a deep link to bind the chat' do
      expect {
        # Body-less POST, like the real (axios) client sends — no JSON content type.
        post '/api/v1/telegram/connection', headers: auth_headers
      }.to change { user.reload.telegram_connection }.from(nil).to(be_present)

      expect(response).to have_http_status(:success)
      expect(json[:deep_link]).to include('start=')
    end
  end

  describe 'DELETE /api/v1/telegram/connection' do
    before { create(:telegram_connection, :linked, user:) }

    it 'unlinks the connection' do
      expect {
        delete '/api/v1/telegram/connection', headers: auth_headers
      }.to change { user.reload.telegram_connection }.to(nil)
      expect(response).to have_http_status(:no_content)
    end
  end
end
