# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::Scrapers::Etcareers do
  subject(:results) { described_class.new.scrape }

  let(:listing_html) { file_fixture('jobs/etcareers/listing.html').read }
  let(:detail_html) { file_fixture('jobs/etcareers/detail.html').read }
  let(:empty_listing) { '<!DOCTYPE html><html><body><ul></ul></body></html>' }
  let(:detail_slug) { 'gift-real-estate-junior-accountant-job-vacancy-2026-0925d41f' }

  after { Prosopite.resume }

  before do
    # The per-job skip_detail? freshness check issues one indexed Job.exists?
    # lookup per listing — legitimate for a scraper, but Prosopite flags it.
    Prosopite.pause
    stub_request(:get, 'https://etcareers.com/jobs?page=1')
      .to_return(status: 200, body: listing_html, headers: { 'Content-Type' => 'text/html' })
    # The listing links to page=2; an empty page halts pagination.
    stub_request(:get, 'https://etcareers.com/jobs?page=2')
      .to_return(status: 200, body: empty_listing, headers: { 'Content-Type' => 'text/html' })
    stub_request(:get, "https://etcareers.com/jobs/#{detail_slug}")
      .to_return(status: 200, body: detail_html, headers: { 'Content-Type' => 'text/html' })
    # The other two listed jobs have no detail stub; a 404 makes them skip cleanly.
    stub_request(:get, %r{https://etcareers\.com/jobs/(nisir|mcm)})
      .to_return(status: 404, body: '')
  end

  it 'parses the JobPosting JSON-LD and the on-page apply link' do
    expect(results.size).to eq(1)

    job = results.first
    expect(job).to include(
      source: 'etcareers',
      source_uid: detail_slug,
      url: "https://etcareers.com/jobs/#{detail_slug}",
      apply_url: 'mailto:hr@giftrealestate.com.et',
      title: 'Gift Real Estate – Junior Accountant Job Vacancy 2026',
      company_name: 'Gift Real Estate PLC',
      location: 'Addis Ababa, Ethiopia',
      region: 'Addis Ababa',
      employment_type: 'full_time',
      posted_on: Date.new(2026, 6, 24),
      deadline_on: Date.new(2026, 8, 3)
    )
    expect(job[:description]).to include('Junior Accountant')
    expect(job[:metadata]).to include(country: 'Ethiopia', jobboardly_id: 13_176_892)
  end
end
