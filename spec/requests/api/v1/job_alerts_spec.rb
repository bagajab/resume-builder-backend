# frozen_string_literal: true

describe 'API::V1::JobAlerts' do
  let(:user) { create(:user) }

  before do
    Flipper.enable(:job_alerts)
    Prosopite.pause
  end

  after { Prosopite.resume }

  describe 'GET /api/v1/job_alerts' do
    before do
      create(:job_alert, user:, name: 'Mine')
      create(:job_alert, name: 'Someone else')
    end

    it 'requires authentication' do
      get '/api/v1/job_alerts'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns only the current user alerts' do
      get '/api/v1/job_alerts', headers: auth_headers

      expect(response).to have_http_status(:success)
      expect(json[:job_alerts].pluck('name')).to contain_exactly('Mine')
    end

    it 'is hidden when the feature flag is off' do
      Flipper.disable(:job_alerts)
      get '/api/v1/job_alerts', headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/job_alerts' do
    let(:params) do
      { job_alert: { name: 'Ruby roles', titles: ['Ruby Engineer'], keywords: ['rails'], frequency: 'daily' } }
    end

    it 'creates an alert for the current user' do
      expect {
        post '/api/v1/job_alerts', params:, headers: auth_headers, as: :json
      }.to change(user.job_alerts, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json[:name]).to eq('Ruby roles')
      expect(json[:frequency]).to eq('daily')
    end

    it 'rejects an invalid alert' do
      post '/api/v1/job_alerts', params: { job_alert: { name: '' } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'PATCH /api/v1/job_alerts/:id' do
    let(:alert) { create(:job_alert, user:, name: 'Old') }

    it 'updates the alert' do
      patch "/api/v1/job_alerts/#{alert.id}", params: { job_alert: { name: 'New' } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:success)
      expect(alert.reload.name).to eq('New')
    end

    it 'forbids updating another user alert' do
      other = create(:job_alert, name: 'Theirs')
      patch "/api/v1/job_alerts/#{other.id}", params: { job_alert: { name: 'Hacked' } }, headers: auth_headers,
                                              as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'pause / resume' do
    let(:alert) { create(:job_alert, user:) }

    it 'pauses and resumes' do
      # Body-less POSTs (no JSON content type) must not be rejected by the API guard.
      post "/api/v1/job_alerts/#{alert.id}/pause", headers: auth_headers
      expect(alert.reload).to be_paused

      post "/api/v1/job_alerts/#{alert.id}/resume", headers: auth_headers
      expect(alert.reload).to be_active
    end
  end

  describe 'DELETE /api/v1/job_alerts/:id' do
    let!(:alert) { create(:job_alert, user:) }

    it 'deletes the alert' do
      expect {
        delete "/api/v1/job_alerts/#{alert.id}", headers: auth_headers, as: :json
      }.to change(user.job_alerts, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'GET /api/v1/job_alerts/:id/notifications' do
    let(:alert) { create(:job_alert, user:) }

    before { create(:job_alert_notification, job_alert: alert, user:) }

    it 'returns the alert history with matched jobs' do
      get "/api/v1/job_alerts/#{alert.id}/notifications", headers: auth_headers
      expect(response).to have_http_status(:success)
      expect(json[:notifications].size).to eq(1)
      expect(json[:notifications].first[:job]).to be_present
    end
  end

  describe 'POST /api/v1/job_alerts/preview' do
    before { create(:job, title: 'Ruby Engineer') }

    it 'returns matching jobs for unsaved criteria' do
      post '/api/v1/job_alerts/preview',
           params: { job_alert: { name: 'preview', titles: ['Ruby Engineer'] } }, headers: auth_headers,
           as: :json

      expect(response).to have_http_status(:success)
      expect(json[:jobs].pluck('title')).to include('Ruby Engineer')
    end
  end
end
