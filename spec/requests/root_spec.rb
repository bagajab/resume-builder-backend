# frozen_string_literal: true

require 'rails_helper'

describe 'GET /' do
  before do
    get root_path
  end

  it 'returns status 200 ok' do
    expect(response).to be_successful
  end

  it 'returns api metadata' do
    expect(json).to include(
      'name' => 'Resume Builder API',
      'status' => 'online',
      'docs' => '/api-docs',
      'health' => '/api/v1/status'
    )
  end
end
