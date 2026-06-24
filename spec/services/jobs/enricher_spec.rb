# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::Enricher do
  let(:client) { instance_double(Jobs::Ai::GeminiClient) }

  let(:raw) do
    {
      'summary' => 'A senior Rails role in Addis.',
      'clean_description' => 'Build and ship APIs.',
      'category' => 'Information Technology',
      'employment_type' => 'full_time',
      'seniority' => 'senior',
      'experience_years_min' => 5,
      'remote_type' => 'remote',
      'salary_min' => 40_000,
      'salary_max' => 60_000,
      'salary_currency' => 'ETB',
      'salary_period' => 'month',
      'skills' => %w[Ruby Rails],
      'languages' => %w[English]
    }
  end

  before { allow(described_class).to receive(:enabled?).and_return(true) }

  describe '#call' do
    it 'enriches a pending job and writes the normalized profile' do
      allow(client).to receive(:generate_json).and_return(raw)
      job = create(:job, enrichment_status: 'pending')

      described_class.new(job, client:).call

      expect(job.reload).to have_attributes(
        ai_summary: 'A senior Rails role in Addis.',
        ai_description: 'Build and ship APIs.',
        category: 'Information Technology',
        seniority: 'senior',
        remote_type: 'remote',
        remote: true, # synced from remote_type
        salary_min: 40_000,
        salary_max: 60_000,
        salary_currency: 'ETB',
        skills: %w[Ruby Rails],
        enrichment_status: 'enriched',
        enrichment_version: described_class::ENRICHMENT_VERSION,
        enrichment_model: Jobs::Ai::GeminiClient::MODEL
      )
      expect(job.content_hash).to be_present
      expect(job.enriched_at).to be_present
    end

    it 'no-ops when the job is already enriched for the same content' do
      allow(client).to receive(:generate_json) # make it a spy
      job = create(:job, enrichment_status: 'pending')
      job.update!(content_hash: described_class.content_hash(job),
                  enrichment_status: 'enriched',
                  enrichment_version: described_class::ENRICHMENT_VERSION)

      described_class.new(job, client:).call

      expect(client).not_to have_received(:generate_json)
    end

    it 'marks the job failed when the model call errors' do
      allow(client).to receive(:generate_json).and_raise(Jobs::Ai::GeminiClient::Error, 'boom')
      job = create(:job, enrichment_status: 'pending')

      described_class.new(job, client:).call

      expect(job.reload.enrichment_status).to eq('failed')
    end

    it 'does nothing when enrichment is disabled' do
      allow(described_class).to receive(:enabled?).and_return(false)
      job = create(:job)

      described_class.new(job, client:).call

      expect(job.reload.enrichment_status).to eq('pending')
    end
  end

  describe '.fresh?' do
    it 'is true only for a recently-enriched job at the current version' do
      url = 'https://ethiojobs.net/jobs/fresh'
      create(:job, url:, enrichment_status: 'enriched',
                   enrichment_version: described_class::ENRICHMENT_VERSION, enriched_at: 1.day.ago)

      expect(described_class.fresh?(url)).to be(true)
    end

    it 'is false for a stale or pending enrichment' do
      stale = create(:job, enrichment_status: 'enriched',
                           enrichment_version: described_class::ENRICHMENT_VERSION,
                           enriched_at: (described_class::FRESH_FOR + 1.day).ago)
      pending = create(:job, enrichment_status: 'pending')

      expect(described_class.fresh?(stale.url)).to be(false)
      expect(described_class.fresh?(pending.url)).to be(false)
    end
  end

  describe '.content_hash' do
    it 'is stable for the same content and changes when the source changes' do
      job = create(:job, description: 'Original')
      original = described_class.content_hash(job)

      expect(described_class.content_hash(job)).to eq(original)

      job.description = 'Changed'
      expect(described_class.content_hash(job)).not_to eq(original)
    end
  end
end
