# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::Scrapers::Ngojobs do
  subject(:results) { described_class.new.scrape }

  let(:listing_html) { file_fixture('jobs/ngojobs/listing.html').read }
  let(:detail_html) { file_fixture('jobs/ngojobs/detail.html').read }
  let(:empty_listing) { '<!DOCTYPE html><html><body><ul></ul></body></html>' }
  let(:detail_slug) { 'woreda-program-supervisors-12-positions-mqt9ntmm' }

  after { Prosopite.resume }

  before do
    # Per-job skip_detail? freshness lookups are legitimate here; Prosopite flags
    # the repeated indexed query, so pause it for the scrape.
    Prosopite.pause
    stub_request(:get, 'https://ngojobs.et/jobs?page=1')
      .to_return(status: 200, body: listing_html, headers: { 'Content-Type' => 'text/html' })
    stub_request(:get, 'https://ngojobs.et/jobs?page=2')
      .to_return(status: 200, body: empty_listing, headers: { 'Content-Type' => 'text/html' })
    stub_request(:get, "https://ngojobs.et/jobs/#{detail_slug}")
      .to_return(status: 200, body: detail_html, headers: { 'Content-Type' => 'text/html' })
    stub_request(:get, %r{https://ngojobs\.et/jobs/(warehouse-assistant|internship)})
      .to_return(status: 404, body: '')
  end

  it 'parses the JobPosting JSON-LD and uses the JSON-LD url as the apply link' do
    expect(results.size).to eq(1)

    job = results.first
    expect(job).to include(
      source: 'ngojobs',
      source_uid: detail_slug,
      url: "https://ngojobs.et/jobs/#{detail_slug}",
      # ngojobs puts the real (external) apply target in the JSON-LD url.
      apply_url: a_string_starting_with('https://docs.google.com/forms/'),
      company_name: 'Hanns R. Neumann Stiftung (HRNS)',
      location: 'Bahir Dar, Ethiopia',
      region: 'Bahir Dar',
      employment_type: 'full_time',
      posted_on: Date.new(2026, 6, 24),
      deadline_on: Date.new(2026, 6, 26)
    )
    expect(job[:description]).to be_present
  end
end
