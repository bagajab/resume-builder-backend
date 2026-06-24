# frozen_string_literal: true

require 'openssl'

module Telegram
  # Verifies a Telegram Mini App `initData` string per Telegram's WebApp auth spec:
  #
  #   secret_key   = HMAC_SHA256(key: "WebAppData", data: bot_token)
  #   data_check   = sorted "key=value" lines (all fields except `hash`), \n-joined
  #   expected     = hex(HMAC_SHA256(key: secret_key, data: data_check))
  #   valid        = secure_compare(expected, initData.hash) && fresh(auth_date)
  #
  # Returns the parsed user on success, nil on any failure (bad signature, stale
  # auth_date, missing/garbled fields). This is the ONLY thing that authenticates a
  # Mini App request, so it must be run on every call.
  class WebAppData
    MAX_AGE = 24.hours

    Result = Data.define(:user_id, :username, :first_name, :language_code, :auth_date)

    def self.verify(init_data, bot_token: Telegram.config.bot_token, max_age: MAX_AGE)
      new(init_data, bot_token:, max_age:).verify
    end

    def initialize(init_data, bot_token:, max_age:)
      @init_data = init_data.to_s
      @bot_token = bot_token.to_s
      @max_age = max_age
    end

    def verify
      return if @init_data.blank? || @bot_token.blank?

      pairs = URI.decode_www_form(@init_data).to_h
      provided = pairs.delete('hash')
      return if provided.blank?

      return unless valid_signature?(pairs, provided)
      return unless fresh?(pairs['auth_date'])

      build_result(pairs)
    rescue ArgumentError
      nil # malformed query string
    end

    private

    def valid_signature?(pairs, provided)
      secret_key = OpenSSL::HMAC.digest('SHA256', 'WebAppData', @bot_token)
      expected = OpenSSL::HMAC.hexdigest('SHA256', secret_key, data_check_string(pairs))
      ActiveSupport::SecurityUtils.secure_compare(expected, provided)
    end

    # All received fields except `hash`, as "key=value" lines sorted by key.
    def data_check_string(pairs)
      pairs.sort.map { |key, value| "#{key}=#{value}" }.join("\n")
    end

    def fresh?(auth_date)
      seconds = Integer(auth_date, exception: false)
      return false if seconds.nil?

      Time.zone.at(seconds) > @max_age.ago
    end

    def build_result(pairs)
      user = JSON.parse(pairs['user'].to_s)
      Result.new(
        user_id: user['id'], username: user['username'], first_name: user['first_name'],
        language_code: user['language_code'], auth_date: pairs['auth_date'].to_i
      )
    rescue JSON::ParserError
      nil
    end
  end
end
