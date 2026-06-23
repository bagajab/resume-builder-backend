# frozen_string_literal: true

describe 'API::V1::Telegram::Webhooks' do
  let(:secret) { 'super-secret' }
  let(:payload) { { update_id: 1, message: { chat: { id: 1 }, text: '/start x' } } }

  before do
    allow(Telegram).to receive(:config).and_return(
      Telegram::Config.new(bot_token: 't', bot_username: 'bot', webhook_secret: secret, webhook_url: nil)
    )
  end

  it 'rejects requests without the secret token header' do
    post '/api/v1/telegram/webhook', params: payload.to_json,
                                     headers: { 'CONTENT_TYPE' => 'application/json' }
    expect(response).to have_http_status(:unauthorized)
  end

  it 'processes updates when the secret token matches' do
    allow(Telegram::UpdateProcessor).to receive(:call)

    post '/api/v1/telegram/webhook', params: payload.to_json, headers: {
      'CONTENT_TYPE' => 'application/json',
      'X-Telegram-Bot-Api-Secret-Token' => secret
    }

    expect(response).to have_http_status(:ok)
    expect(Telegram::UpdateProcessor).to have_received(:call).with(hash_including(update_id: 1))
  end
end
