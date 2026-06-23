# frozen_string_literal: true

describe JobAlerts::ScanService do
  before { Prosopite.pause }
  after { Prosopite.resume }

  let(:user) { create(:user) }
  let!(:alert) { create(:job_alert, user:, titles: ['Software Engineer']) }
  let!(:job) { create(:job, title: 'Senior Software Engineer') }

  it 'creates a notification for a matching job' do
    expect { described_class.call }.to change(JobAlertNotification, :count).by(1)
    notification = JobAlertNotification.last
    expect(notification.job_alert).to eq(alert)
    expect(notification.job).to eq(job)
    expect(notification.user).to eq(user)
  end

  it 'records last_run_at on the alert' do
    described_class.call
    expect(alert.reload.last_run_at).to be_present
  end

  it 'never notifies the same (alert, job) pair twice' do
    described_class.call
    # Force a re-scan of the same job; the unique index is the dedup guarantee.
    alert.update!(last_run_at: nil)
    expect { described_class.call }.not_to change(JobAlertNotification, :count)
  end

  it 'ignores paused alerts' do
    alert.paused!
    expect { described_class.call }.not_to change(JobAlertNotification, :count)
  end

  it 'does not notify for a non-matching job' do
    alert.update!(titles: ['Accountant'], last_run_at: nil)
    expect { described_class.call }.not_to change(JobAlertNotification, :count)
  end
end
