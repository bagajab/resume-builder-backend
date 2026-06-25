# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::Scrapers::Palmjobs do
  subject(:results) { described_class.new.scrape }

  let(:detail_html) { file_fixture('jobs/palmjobs/detail.html').read }
  let(:uuid) { '666b9813-32bc-42e0-b2e9-4f7b5bc82ac2' }
  # A flat urlset mixing a job-detail UUID with a category page — only the UUID
  # should be enumerated.
  let(:sitemap_xml) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        <url><loc>https://palmjobs.et/jobs</loc></url>
        <url><loc>https://palmjobs.et/jobs/addis-ababa/technology</loc></url>
        <url><loc>https://palmjobs.et/jobs/#{uuid}</loc></url>
      </urlset>
    XML
  end

  after { Prosopite.resume }

  before do
    # Per-job skip_detail? freshness lookups are legitimate here; Prosopite flags
    # the repeated indexed query, so pause it for the scrape.
    Prosopite.pause
    stub_request(:get, 'https://palmjobs.et/sitemap.xml')
      .to_return(status: 200, body: sitemap_xml, headers: { 'Content-Type' => 'application/xml' })
    stub_request(:get, "https://palmjobs.et/jobs/#{uuid}")
      .to_return(status: 200, body: detail_html, headers: { 'Content-Type' => 'text/html' })
  end

  it 'enumerates job UUIDs from the sitemap and parses __NEXT_DATA__' do
    expect(results.size).to eq(1)

    job = results.first
    expect(job).to include(
      source: 'palmjobs',
      source_uid: uuid,
      url: "https://palmjobs.et/jobs/#{uuid}",
      title: 'Homebased Consultant - Entrepreneurship Financing Mapping',
      company_name: 'IOM - International Organization for Migration',
      location: 'Remote | Addis Ababa',
      region: 'Addis Ababa',
      remote: true,
      category: 'NGO & Development',
      salary_currency: 'ETB',
      apply_url: 'https://www.impactpool.org/jobs/1222043',
      posted_on: Date.new(2026, 6, 25),
      deadline_on: Date.new(2026, 7, 7)
    )
    expect(job[:tags]).to include('communication')
    expect(job[:description]).to include('IOM')
    expect(job[:metadata]).to include(is_aggregated: true, source_name: 'Impactpool')
  end
end
