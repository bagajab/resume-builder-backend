# frozen_string_literal: true

describe JobAlert do
  it 'is valid with the factory defaults' do
    expect(build(:job_alert)).to be_valid
  end

  it 'requires a name' do
    alert = build(:job_alert, name: nil)
    expect(alert).not_to be_valid
    expect(alert.errors[:name]).to be_present
  end

  it 'rejects an unknown remote preference' do
    alert = build(:job_alert, remote_preference: 'martian')
    expect(alert).not_to be_valid
    expect(alert.errors[:remote_preference]).to be_present
  end

  it 'rejects a salary_max below salary_min' do
    alert = build(:job_alert, salary_min: 50_000, salary_max: 10_000)
    expect(alert).not_to be_valid
    expect(alert.errors[:salary_max]).to be_present
  end

  it 'exposes frequency and status enums' do
    alert = build(:job_alert, :daily, :paused)
    expect(alert).to be_daily
    expect(alert).to be_paused
  end
end
