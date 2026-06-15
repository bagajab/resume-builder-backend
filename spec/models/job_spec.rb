# frozen_string_literal: true

# == Schema Information
#
# Table name: jobs
#
#  id               :bigint           not null, primary key
#  active           :boolean          default(TRUE), not null
#  apply_url        :string
#  category         :string
#  company_logo_url :string
#  company_name     :string
#  deadline_on      :date
#  description      :text
#  education_level  :string
#  employment_type  :string
#  experience_level :string
#  first_seen_at    :datetime         not null
#  last_seen_at     :datetime         not null
#  location         :string
#  metadata         :jsonb            not null
#  posted_on        :date
#  region           :string
#  remote           :boolean          default(FALSE), not null
#  salary           :string
#  source           :string           not null
#  source_uid       :string
#  summary          :text
#  tags             :string           default([]), not null, is an Array
#  title            :string           not null
#  url              :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_jobs_on_active                 (active)
#  index_jobs_on_deadline_on            (deadline_on)
#  index_jobs_on_posted_on              (posted_on)
#  index_jobs_on_source                 (source)
#  index_jobs_on_source_and_source_uid  (source,source_uid)
#  index_jobs_on_tags                   (tags) USING gin
#  index_jobs_on_url                    (url) UNIQUE
#
require 'rails_helper'

RSpec.describe Job do
  describe 'validations' do
    subject { build(:job) }

    it { is_expected.to be_valid }

    it 'requires a title' do
      expect(build(:job, title: nil)).not_to be_valid
    end

    it 'requires a url' do
      expect(build(:job, url: nil)).not_to be_valid
    end

    it 'enforces a unique url' do
      create(:job, url: 'https://ethiojobs.net/jobs/dup')
      expect(build(:job, url: 'https://ethiojobs.net/jobs/dup')).not_to be_valid
    end

    it 'rejects an unknown source' do
      expect(build(:job, source: 'craigslist')).not_to be_valid
    end

    it 'allows a nil employment_type but rejects an unknown one' do
      expect(build(:job, employment_type: nil)).to be_valid
      expect(build(:job, employment_type: 'whenever')).not_to be_valid
    end
  end

  describe 'scopes' do
    # Seeding several rows fires the url uniqueness-validation SELECT repeatedly,
    # which the suite's Prosopite N+1 guard would flag. Pause it during setup
    # only (defined before the let!s so this before-hook runs first).
    before { Prosopite.pause }
    after { Prosopite.resume }

    let!(:active_job) { create(:job, source: 'hahu_jobs') }
    let!(:inactive_job) { create(:job, :inactive) }
    let!(:remote_job) { create(:job, :remote) }
    let!(:expired_job) { create(:job, :expired) }

    it '.live returns only active jobs' do
      expect(described_class.live).to include(active_job, remote_job, expired_job)
      expect(described_class.live).not_to include(inactive_job)
    end

    it '.from_source filters by source' do
      expect(described_class.from_source('hahu_jobs')).to contain_exactly(active_job)
    end

    it '.remote returns remote jobs' do
      expect(described_class.remote).to contain_exactly(remote_job)
    end

    it '.open_for_application excludes past deadlines' do
      expect(described_class.open_for_application).not_to include(expired_job)
      expect(described_class.open_for_application).to include(active_job)
    end
  end

  describe '#expired?' do
    it 'is true once the deadline has passed' do
      expect(build(:job, :expired)).to be_expired
      expect(build(:job, deadline_on: Date.current)).not_to be_expired
      expect(build(:job, deadline_on: nil)).not_to be_expired
    end
  end

  describe '#days_until_deadline' do
    it 'returns the day count, or nil without a deadline' do
      expect(build(:job, deadline_on: 5.days.from_now.to_date).days_until_deadline).to eq(5)
      expect(build(:job, deadline_on: nil).days_until_deadline).to be_nil
    end
  end
end
