# frozen_string_literal: true

# Namespace + runtime configuration for the Telegram integration. Reads from ENV
# on every call so values can be stubbed in tests and picked up from dotenv in dev.
module Telegram
  Config = Data.define(:bot_token, :bot_username, :webhook_secret, :webhook_url) do
    def configured? = bot_token.present?
  end

  def self.config
    Config.new(
      bot_token: ENV.fetch('TELEGRAM_BOT_TOKEN', nil),
      bot_username: ENV.fetch('TELEGRAM_BOT_USERNAME', nil),
      webhook_secret: ENV.fetch('TELEGRAM_WEBHOOK_SECRET', nil),
      webhook_url: ENV.fetch('TELEGRAM_WEBHOOK_URL', nil)
    )
  end
end
