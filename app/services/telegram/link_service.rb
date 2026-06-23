# frozen_string_literal: true

module Telegram
  # Creates (or refreshes) a pending TelegramConnection for a user and returns the
  # deep link they should open to bind their Telegram chat.
  class LinkService
    Result = Data.define(:connection, :deep_link)

    def self.call(...) = new(...).call

    def initialize(user:)
      @user = user
    end

    def call
      connection = @user.telegram_connection || @user.build_telegram_connection
      connection.fresh_link_token!
      Result.new(connection:, deep_link: connection.deep_link)
    end
  end
end
