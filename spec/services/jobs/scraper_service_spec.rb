# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::ScraperService do
  let(:record) do
    {
      source: 'ethiojobs',
      source_uid: 'abc-designer',
      url: 'https://ethiojobs.net/jobs/abc-designer',
      title: 'Graphic Designer',
      company_name: 'Skylight',
      first_seen_at: Time.current,
      last_seen_at: Time.current
    }
  end

  before do
    # Scraping is gated on Gemini enrichment being configured; enable it by default.
    allow(Jobs::Enricher).to receive(:enabled?).and_return(true)
    # Stub every source so no network is touched; only ethiojobs returns data.
    stub_scraper(Jobs::Scrapers::Ethiojobs, [record])
    stub_scraper(Jobs::Scrapers::EthiopianReporter, [])
    stub_scraper(Jobs::Scrapers::HahuJobs, [])
  end

  def stub_scraper(klass, records)
    allow(klass).to receive(:new).and_return(instance_double(klass, scrape: records))
  end

  it 'creates a job from scraped data' do
    expect { described_class.call }.to change(Job, :count).by(1)

    job = Job.find_by(url: record[:url])
    expect(job).to have_attributes(title: 'Graphic Designer', source: 'ethiojobs', active: true)
    expect(job.first_seen_at).to be_present
    expect(job.last_seen_at).to be_present
  end

  it 'is idempotent and refreshes last_seen_at instead of duplicating' do
    described_class.call
    original = Job.find_by(url: record[:url])

    travel_to(1.day.from_now) do
      expect { described_class.call }.not_to change(Job, :count)
      original.reload
      expect(original.last_seen_at).to be > original.first_seen_at
    end
  end

  it 'deactivates jobs from a source that are no longer listed' do
    stale = create(:job, source: 'ethiojobs', url: 'https://ethiojobs.net/jobs/gone', active: true)

    described_class.call

    expect(stale.reload.active).to be(false)
    expect(Job.find_by(url: record[:url]).active).to be(true)
  end

  it 'does not deactivate other sources when one source returns nothing' do
    untouched = create(:job, source: 'hahu_jobs', active: true)

    described_class.call

    expect(untouched.reload.active).to be(true)
  end

  it 'returns a per-source result summary' do
    results = described_class.call

    ethiojobs = results.find { |r| r.source == 'ethiojobs' }
    expect(ethiojobs.created).to eq(1)
    expect(ethiojobs.upserted).to eq(1)
    # Ethiojobs only for now (EthiopianReporter / HahuJobs are disabled).
    expect(results.map(&:source)).to contain_exactly('ethiojobs')
  end

  it 'skips the whole run when Gemini enrichment is not configured' do
    allow(Jobs::Enricher).to receive(:enabled?).and_return(false)

    expect { described_class.call }.not_to change(Job, :count)
    expect(described_class.call).to eq([])
  end

  describe 'enrichment wiring' do
    include ActiveJob::TestHelper

    context 'when enrichment is enabled' do
      before { allow(Jobs::Enricher).to receive(:enabled?).and_return(true) }

      it 'stamps a content hash and enqueues enrichment for a new job' do
        expect { described_class.call }.to have_enqueued_job(Jobs::EnrichJob)
        expect(Job.find_by(url: record[:url]).content_hash).to be_present
      end

      it 'does not re-enqueue when an enriched job is seen with unchanged content' do
        described_class.call # first run creates + enqueues
        Job.find_by(url: record[:url]).update!(
          enrichment_status: 'enriched', enrichment_version: Jobs::Enricher::ENRICHMENT_VERSION
        )

        expect { described_class.call }.not_to have_enqueued_job(Jobs::EnrichJob)
      end

      it 're-enqueues and marks pending when the source content changes' do
        described_class.call
        job = Job.find_by(url: record[:url])
        job.update!(enrichment_status: 'enriched', enrichment_version: Jobs::Enricher::ENRICHMENT_VERSION)

        stub_scraper(Jobs::Scrapers::Ethiojobs, [record.merge(title: 'Senior Graphic Designer')])

        expect { described_class.call }.to have_enqueued_job(Jobs::EnrichJob)
        expect(job.reload.enrichment_status).to eq('pending')
      end
    end

    it 'does not enqueue when enrichment is disabled' do
      allow(Jobs::Enricher).to receive(:enabled?).and_return(false)

      expect { described_class.call }.not_to have_enqueued_job(Jobs::EnrichJob)
    end

    it 'refreshes a job from a refresh-only marker without re-enqueuing' do
      allow(Jobs::Enricher).to receive(:enabled?).and_return(true)
      existing = create(:job, source: 'ethiojobs', url: record[:url], active: false)
      stub_scraper(Jobs::Scrapers::Ethiojobs, [{ source: 'ethiojobs', url: record[:url], refresh_only: true }])

      expect { described_class.call }.not_to have_enqueued_job(Jobs::EnrichJob)
      expect(existing.reload).to have_attributes(active: true)
    end
  end
end
