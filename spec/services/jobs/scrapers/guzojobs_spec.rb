# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::Scrapers::Guzojobs do
  subject(:results) { described_class.new.scrape }

  let(:listing_html) { file_fixture('jobs/guzojobs/listing.html').read }
  let(:detail_json) { file_fixture('jobs/guzojobs/detail.json').read }

  after { Prosopite.resume }

  before do
    # Per-job skip_detail? freshness lookups are legitimate here; Prosopite flags
    # the repeated indexed query, so pause it for the scrape.
    Prosopite.pause
    # Page 1 is the bare /jobs/ index (/jobs/page/1/ 301s to it).
    stub_request(:get, 'https://guzojobs.com/jobs/')
      .to_return(status: 200, body: listing_html, headers: { 'Content-Type' => 'text/html' })
    # The listing 404s past the last page — the end-of-pagination signal.
    stub_request(:get, 'https://guzojobs.com/jobs/page/2/')
      .to_return(status: 404, body: '')
    # WP REST supplies the full description for every card.
    stub_request(:get, %r{https://guzojobs\.com/wp-json/wp/v2/noo_job/\d+})
      .to_return(status: 200, body: detail_json, headers: { 'Content-Type' => 'application/json' })
  end

  it 'reads company/dates/taxonomy from the listing card and the body from WP REST' do
    expect(results.size).to eq(3)

    job = results.find { |record| record[:source_uid] == '18377' }
    expect(job).to include(
      source: 'guzojobs',
      source_uid: '18377',
      url: 'https://guzojobs.com/jobs/social-media-manager-addis-ababa-4/',
      title: 'Social Media Manager Addis Ababa',
      company_name: 'Skylight Technologies PLC',
      location: 'Addis Ababa',
      category: 'It Software',
      employment_type: 'full_time',
      posted_on: Date.new(2026, 6, 25),
      deadline_on: Date.new(2026, 7, 10)
    )
    expect(job[:description]).to include('About the Role')
    expect(job[:metadata]).to eq(wp_id: 18_377)
  end
end
