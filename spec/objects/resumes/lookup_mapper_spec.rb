# frozen_string_literal: true

describe Resumes::LookupMapper do
  let(:user) { create(:user) }

  before { Prosopite.pause }
  after { Prosopite.resume }

  it 'rewrites a value to its approved canonical casing' do
    create(:job_title, value: 'Senior Engineer', status: 'approved')
    parsed = { profile: { job_title: 'senior engineer', interests: [], languages: [] } }

    described_class.new(user: user).map!(parsed)

    expect(parsed[:profile][:job_title]).to eq('Senior Engineer')
  end

  it 'creates a category-scoped pending row for an unknown skill' do
    parsed = { skills: [{ name: 'Svelte', category: 'technical' }] }

    expect { described_class.new(user: user).map!(parsed) }
      .to change { SkillOption.pending.where(value: 'Svelte', category: 'technical').count }.by(1)

    expect(parsed[:skills].first[:name]).to eq('Svelte')
    expect(SkillOption.pending.find_by(value: 'Svelte').submitted_by_user).to eq(user)
  end

  it 'reuses an existing pending row instead of duplicating it' do
    create(:job_title, value: 'Designer', status: 'pending', submitted_by_user: user)
    parsed = { profile: { job_title: 'designer', interests: [], languages: [] } }

    expect { described_class.new(user: user).map!(parsed) }.not_to change(JobTitle, :count)
    expect(parsed[:profile][:job_title]).to eq('Designer')
  end

  it 'leaves blank values untouched' do
    parsed = { profile: { job_title: nil, industry: '', interests: [], languages: [] } }

    expect { described_class.new(user: user).map!(parsed) }.not_to change(JobTitle, :count)
    expect(parsed[:profile][:job_title]).to be_nil
  end
end
