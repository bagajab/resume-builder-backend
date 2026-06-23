# frozen_string_literal: true

describe JobAlerts::Matcher do
  before { Prosopite.pause }
  after { Prosopite.resume }

  def match(alert_attrs, job_attrs)
    alert = build(:job_alert, alert_attrs)
    job = build(:job, job_attrs)
    described_class.call(alert, job)
  end

  it 'matches on a strong title overlap' do
    result = match({ titles: ['Software Engineer'] }, { title: 'Senior Software Engineer' })
    expect(result).to be_matched
    expect(result.score).to be > 0.9
  end

  it 'does not match an unrelated title' do
    result = match({ titles: ['Accountant'] }, { title: 'Software Engineer' })
    expect(result).not_to be_matched
  end

  it 'scores keyword presence across the job body' do
    result = match(
      { titles: [], keywords: %w[ruby rails] },
      { title: 'Backend Developer', description: 'We use Ruby on Rails daily.' }
    )
    expect(result).to be_matched
  end

  it 'treats an alert with only hard filters as a match when they pass' do
    result = match({ titles: [], employment_types: ['full_time'] }, { employment_type: 'full_time' })
    expect(result).to be_matched
    expect(result.score).to eq(1.0)
  end

  it 'rejects on an employment-type mismatch (hard filter)' do
    result = match({ titles: ['Engineer'], employment_types: ['full_time'] },
                   { title: 'Engineer', employment_type: 'internship' })
    expect(result).not_to be_matched
  end

  it 'rejects an on-site-only job for a remote-only alert' do
    result = match({ titles: [], remote_preference: 'remote' }, { remote: false })
    expect(result).not_to be_matched
  end

  it 'excludes jobs below the salary floor but keeps unknown salaries' do
    below = match({ titles: [], salary_min: 30_000 }, { salary: '15,000 ETB' })
    unknown = match({ titles: [], salary_min: 30_000 }, { salary: nil, employment_type: 'full_time' })
    expect(below).not_to be_matched
    expect(unknown).to be_matched
  end
end
