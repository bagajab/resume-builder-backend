# frozen_string_literal: true

require 'rails_helper'

describe 'API::V1::Telegram::MiniApp' do
  let(:bot_token) { 'mini-app-bot-token' }
  let(:user) { create(:user) }
  let(:job_alert) { create(:job_alert, user:, titles: ['Engineer']) }
  let(:job) { create(:job, title: 'Backend Engineer', category: 'Information Technology', tags: ['ruby']) }
  let(:notification) { create(:job_alert_notification, user:, job_alert:, job:) }

  before do
    create(:telegram_connection, :linked, user:, telegram_user_id:)
    allow(Telegram).to receive(:config).and_return(
      Telegram::Config.new(bot_token:, bot_username: 'bot', webhook_secret: 's', webhook_url: nil)
    )
  end

  # Plain method (not a memoized helper) to keep the example group lean.
  def telegram_user_id = 42

  def init_data(user_id: telegram_user_id, auth_date: Time.current.to_i)
    fields = { 'auth_date' => auth_date.to_s, 'user' => { id: user_id, username: 'bob' }.to_json }
    check = fields.sort.map { |k, v| "#{k}=#{v}" }.join("\n")
    secret = OpenSSL::HMAC.digest('SHA256', 'WebAppData', bot_token)
    hash = OpenSSL::HMAC.hexdigest('SHA256', secret, check)
    URI.encode_www_form(fields.merge('hash' => hash))
  end

  def refine_token(uid: telegram_user_id)
    Telegram::FeedbackToken.generate(notification, telegram_user_id: uid)
  end

  def headers(init: init_data, token: refine_token)
    { 'X-Telegram-Init-Data' => init, 'X-Telegram-Refine-Token' => token }
  end

  def json_headers(extra)
    headers(**extra).merge('CONTENT_TYPE' => 'application/json')
  end

  describe 'GET /api/v1/telegram/mini_app/job_alert' do
    it 'returns the owner alert and the matched job for a valid request' do
      get '/api/v1/telegram/mini_app/job_alert', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json[:alert][:id]).to eq(job_alert.id)
      expect(json[:alert][:titles]).to eq(['Engineer'])
      expect(json[:job][:title]).to eq('Backend Engineer')
      expect(json[:job][:tags]).to eq(['ruby'])
    end

    it 'rejects invalid initData' do
      get '/api/v1/telegram/mini_app/job_alert', headers: headers(init: 'garbage')
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects an invalid refine token' do
      get '/api/v1/telegram/mini_app/job_alert', headers: headers(token: 'nope')
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects when the initData user is not the alert owner' do
      # Token is fine, but the verified Telegram user differs from the owner.
      tok = refine_token
      get '/api/v1/telegram/mini_app/job_alert',
          headers: headers(init: init_data(user_id: 9999), token: tok)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PATCH /api/v1/telegram/mini_app/job_alert' do
    it 'updates only that alert and consumes the single-use token' do
      tok = refine_token

      patch '/api/v1/telegram/mini_app/job_alert',
            params: { job_alert: { titles: ['Senior Engineer'], keywords: ['rails'] } }.to_json,
            headers: json_headers(token: tok)

      expect(response).to have_http_status(:ok)
      expect(job_alert.reload.titles).to eq(['Senior Engineer'])
      expect(job_alert.keywords).to eq(['rails'])
      expect(notification.reload.refine_token_consumed_at).to be_present
    end

    it 'rejects reuse of a consumed token' do
      tok = refine_token
      patch '/api/v1/telegram/mini_app/job_alert',
            params: { job_alert: { titles: ['Once'] } }.to_json, headers: json_headers(token: tok)
      expect(response).to have_http_status(:ok)

      patch '/api/v1/telegram/mini_app/job_alert',
            params: { job_alert: { titles: ['Twice'] } }.to_json, headers: json_headers(token: tok)
      expect(response).to have_http_status(:unauthorized)
      expect(job_alert.reload.titles).to eq(['Once'])
    end
  end
end
