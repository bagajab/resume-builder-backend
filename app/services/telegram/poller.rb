# frozen_string_literal: true

module Telegram
  # Long-polling fallback for local development, where there is no public HTTPS URL
  # for a webhook. Fetches a batch of updates, processes each, and returns the next
  # offset so a caller (the telegram:poll rake task) can loop.
  class Poller
    def self.call(...) = new(...).call

    def initialize(client: Telegram::Client.new, logger: Rails.logger)
      @client = client
      @logger = logger
    end

    def call(offset: nil)
      updates = @client.get_updates(offset:)
      next_offset = offset
      Array(updates).each do |update|
        UpdateProcessor.call(update, client: @client)
        next_offset = update['update_id'].to_i + 1
      end
      next_offset
    end
  end
end
