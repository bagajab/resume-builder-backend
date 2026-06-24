# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Telegram::WebAppData do
  let(:bot_token) { 'test-bot-token' }
  let(:tg_user) { { id: 42, username: 'bob', first_name: 'Bob', language_code: 'en' } }

  # Builds an initData query string signed exactly like Telegram does.
  def init_data(user: tg_user, auth_date: Time.current.to_i, tamper: false)
    fields = { 'auth_date' => auth_date.to_s, 'query_id' => 'AAA', 'user' => user.to_json }
    check = fields.sort.map { |k, v| "#{k}=#{v}" }.join("\n")
    secret = OpenSSL::HMAC.digest('SHA256', 'WebAppData', bot_token)
    hash = OpenSSL::HMAC.hexdigest('SHA256', secret, check)
    hash = "#{hash[0..-2]}0" if tamper
    URI.encode_www_form(fields.merge('hash' => hash))
  end

  it 'verifies a correctly-signed payload and returns the user' do
    result = described_class.verify(init_data, bot_token:)

    expect(result.user_id).to eq(42)
    expect(result.username).to eq('bob')
    expect(result.language_code).to eq('en')
  end

  it 'rejects a tampered hash' do
    expect(described_class.verify(init_data(tamper: true), bot_token:)).to be_nil
  end

  it 'rejects a stale auth_date' do
    expect(described_class.verify(init_data(auth_date: 2.days.ago.to_i), bot_token:)).to be_nil
  end

  it 'rejects a payload signed with a different bot token' do
    expect(described_class.verify(init_data, bot_token: 'other-token')).to be_nil
  end

  it 'rejects blank input' do
    expect(described_class.verify('', bot_token:)).to be_nil
  end
end
