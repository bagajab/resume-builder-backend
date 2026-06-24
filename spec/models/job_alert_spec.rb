# frozen_string_literal: true

# == Schema Information
#
# Table name: job_alerts
#
#  id                :bigint           not null, primary key
#  employment_types  :string           default([]), not null, is an Array
#  experience_levels :string           default([]), not null, is an Array
#  frequency         :integer          default("instant"), not null
#  keywords          :string           default([]), not null, is an Array
#  last_run_at       :datetime
#  locations         :string           default([]), not null, is an Array
#  name              :string           not null
#  remote_preference :string           default("any"), not null
#  salary_currency   :string
#  salary_max        :integer
#  salary_min        :integer
#  status            :integer          default("active"), not null
#  titles            :string           default([]), not null, is an Array
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_job_alerts_on_keywords  (keywords) USING gin
#  index_job_alerts_on_status    (status)
#  index_job_alerts_on_titles    (titles) USING gin
#  index_job_alerts_on_user_id   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
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
