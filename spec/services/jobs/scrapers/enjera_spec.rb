# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::Scrapers::Enjera do
  subject(:results) { described_class.new.scrape }

  let(:listing_html) { file_fixture('jobs/enjera/listing.html').read }
  let(:detail_html) { file_fixture('jobs/enjera/detail.html').read }
  let(:empty_listing) { '<!DOCTYPE html><html><body><ul></ul></body></html>' }
  let(:detail_slug) { 'administrative-assistant-afcfta-607eced8' }

  after { Prosopite.resume }

  before do
    # Per-job skip_detail? freshness lookups are legitimate here; Prosopite flags
    # the repeated indexed query, so pause it for the scrape.
    Prosopite.pause
    stub_request(:get, 'https://enjera.com/jobs?page=1')
      .to_return(status: 200, body: listing_html, headers: { 'Content-Type' => 'text/html' })
    stub_request(:get, 'https://enjera.com/jobs?page=2')
      .to_return(status: 200, body: empty_listing, headers: { 'Content-Type' => 'text/html' })
    stub_request(:get, "https://enjera.com/jobs/#{detail_slug}")
      .to_return(status: 200, body: detail_html, headers: { 'Content-Type' => 'text/html' })
    stub_request(:get, %r{https://enjera\.com/jobs/(field-officer|plant-engineer)})
      .to_return(status: 404, body: '')
  end

  it 'parses the JobPosting JSON-LD and the external apply link' do
    expect(results.size).to eq(1)

    job = results.first
    expect(job).to include(
      source: 'enjera',
      source_uid: detail_slug,
      url: "https://enjera.com/jobs/#{detail_slug}",
      apply_url: a_string_starting_with('https://career2.successfactors.eu/career'),
      title: 'Administrative Assistant - AfCFTA',
      company_name: 'The African Union Commission',
      company_logo_url: a_string_starting_with('https://cdn.jobboardly.com/'),
      employment_type: 'full_time',
      posted_on: Date.new(2026, 6, 18),
      deadline_on: Date.new(2026, 7, 18)
    )
    # enjera's JSON-LD carries only addressCountry.
    expect(job[:location]).to eq('Ethiopia')
    expect(job[:description]).to be_present
  end
end
