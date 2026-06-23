# frozen_string_literal: true

namespace :telegram do
  desc 'Register the Telegram webhook (TELEGRAM_WEBHOOK_URL + TELEGRAM_WEBHOOK_SECRET)'
  task set_webhook: :environment do
    config = Telegram.config
    abort 'TELEGRAM_WEBHOOK_URL is not set' if config.webhook_url.blank?

    Telegram::Client.new.set_webhook(url: config.webhook_url, secret_token: config.webhook_secret)
    puts "Webhook registered: #{config.webhook_url}"
  end

  desc 'Remove the Telegram webhook'
  task delete_webhook: :environment do
    Telegram::Client.new.delete_webhook
    puts 'Webhook deleted'
  end

  desc 'Long-poll Telegram updates (local dev fallback for the webhook). Ctrl-C to stop.'
  task poll: :environment do
    puts 'Polling Telegram updates… (Ctrl-C to stop)'
    poller = Telegram::Poller.new
    offset = nil
    loop do
      offset = poller.call(offset:)
    rescue Telegram::Client::Error => error
      warn "[telegram:poll] #{error.message}"
      sleep 3
    end
  end
end
