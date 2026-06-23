# frozen_string_literal: true

module API
  module V1
    module Telegram
      # Public endpoint Telegram POSTs updates to. Deliberately inherits the bare
      # API controller (no Devise/Pundit) — the request is authenticated solely by
      # the secret token header that Telegram echoes back from setWebhook. Always
      # returns 200 so Telegram doesn't retry on our processing errors.
      class WebhooksController < ActionController::API
        def create
          return head :unauthorized unless valid_secret?

          ::Telegram::UpdateProcessor.call(update_payload)
          head :ok
        end

        private

        def valid_secret?
          expected = ::Telegram.config.webhook_secret
          expected.present? &&
            ActiveSupport::SecurityUtils.secure_compare(
              request.headers['X-Telegram-Bot-Api-Secret-Token'].to_s, expected
            )
        end

        def update_payload
          JSON.parse(request.raw_post).deep_symbolize_keys
        rescue JSON::ParserError
          {}
        end
      end
    end
  end
end
