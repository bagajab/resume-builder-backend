# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::Scrapers::Ethiojobs do
  subject(:results) { described_class.new.scrape }

  let(:listing_html) { file_fixture('jobs/ethiojobs/listing.html').read }
  let(:detail_html) { file_fixture('jobs/ethiojobs/detail.html').read }

  before do
    stub_request(:get, 'https://ethiojobs.net/jobs?page=1')
      .to_return(status: 200, body: listing_html, headers: { 'Content-Type' => 'text/html' })
    stub_request(:get, 'https://ethiojobs.net/job/abc-designer')
      .to_return(status: 200, body: detail_html, headers: { 'Content-Type' => 'text/html' })
    empty_listing = <<~HTML
      <!DOCTYPE html>
      <html><body>
        <script id="__NEXT_DATA__" type="application/json">
          {"props":{"pageProps":{"jobs":{"data":[]}}}}
        </script>
      </body></html>
    HTML
    (2..described_class::MAX_PAGES).each do |page|
      stub_request(:get, "https://ethiojobs.net/jobs?page=#{page}")
        .to_return(status: 200, body: empty_listing, headers: { 'Content-Type' => 'text/html' })
    end
  end

  it 'fetches each job detail page and returns enriched records' do
    expect(results.size).to eq(1)

    job = results.first
    expect(job).to include(
      source: 'ethiojobs',
      source_uid: 'abc-designer',
      url: 'https://ethiojobs.net/job/abc-designer',
      apply_url: 'mailto:jobs@skylight.et',
      title: 'Graphic Designer',
      company_name: 'Skylight',
      company_logo_url: 'https://pub-f30882b481294faa997a4d11ff77ce65.r2.dev/company-logo/42/skylight.png',
      location: 'Addis Ababa, Ethiopia',
      region: 'Addis Ababa',
      remote: true,
      employment_type: 'full_time',
      experience_level: '3-5 years',
      category: 'Design',
      tags: %w[Design Marketing],
      posted_on: Date.new(2026, 6, 1),
      deadline_on: Date.new(2026, 6, 30)
    )
    expect(job[:description]).to include('Short overview.')
    expect(job[:description]).to include('Full requirements and responsibilities.')
    expect(job[:description]).to include('Apply via email.')
    expect(job[:metadata]).to include(
      location_type: 'Remote',
      type_name: ['Full time'],
      career_level: 'Mid Level(3-5 years)',
      skills_mandatory: ['Photoshop'],
      company_logo: 'https://pub-f30882b481294faa997a4d11ff77ce65.r2.dev/company-logo/42/skylight.png'
    )
  end
end
