# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::Enricher::Normalizer do
  def normalize(overrides = {})
    described_class.call({ 'category' => 'Information Technology' }.merge(overrides))
  end

  it 'routes summary/clean_description to the ai_* columns' do
    result = normalize('summary' => '  A great   role.  ', 'clean_description' => 'Full text.')

    expect(result[:ai_summary]).to eq('A great role.')
    expect(result[:ai_description]).to eq('Full text.')
  end

  it 'keeps an exact canonical category' do
    expect(normalize('category' => 'Healthcare & Medical')[:category]).to eq('Healthcare & Medical')
  end

  it 'matches a canonical category case-insensitively' do
    expect(normalize('category' => 'information technology')[:category]).to eq('Information Technology')
  end

  it 'falls back to "Other" for an unknown or blank category' do
    expect(normalize('category' => 'Underwater Basket Weaving')[:category]).to eq('Other')
    expect(normalize('category' => '')[:category]).to eq('Other')
  end

  it 'forces enums into their vocabulary, nil otherwise' do
    result = normalize(
      'employment_type' => 'Full_Time', 'seniority' => 'SENIOR',
      'remote_type' => 'hybrid', 'salary_period' => 'monthly'
    )

    expect(result).to include(employment_type: 'full_time', seniority: 'senior', remote_type: 'hybrid')
    expect(result[:salary_period]).to be_nil # "monthly" is not in SALARY_PERIODS
  end

  it 'clamps experience years to 0..60' do
    expect(normalize('experience_years_min' => 3)[:experience_years_min]).to eq(3)
    expect(normalize('experience_years_min' => 99)[:experience_years_min]).to be_nil
    expect(normalize('experience_years_min' => 'three')[:experience_years_min]).to be_nil
  end

  it 'normalizes list fields to deduped string arrays' do
    result = normalize('skills' => ['Ruby', 'Ruby', '  Rails  ', '', nil, 5])

    expect(result[:skills]).to eq(%w[Ruby Rails 5])
  end

  it 'coerces salary to integers and drops an inverted range' do
    expect(normalize('salary_min' => '1000', 'salary_max' => '2000', 'salary_currency' => 'etb'))
      .to include(salary_min: 1000, salary_max: 2000, salary_currency: 'ETB')

    inverted = normalize('salary_min' => 5000, 'salary_max' => 1000)
    expect(inverted).to include(salary_min: 5000, salary_max: nil)
  end

  it 'returns [] (never nil) for absent list fields' do
    result = normalize
    %i[skills preferred_skills languages benefits responsibilities qualifications].each do |key|
      expect(result[key]).to eq([])
    end
  end
end
