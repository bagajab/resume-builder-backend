# frozen_string_literal: true

module Telegram
  # Short-lived, signed, single-use token that authorizes opening the "refine
  # alert" Mini App for one disliked match. Encodes notification_id + job_alert_id
  # + the owner's telegram_user_id + a random jti, signed (HMAC-SHA256) and
  # expiring in minutes. Raw DB ids are never trusted on their own: the Mini App
  # cross-checks every field against initData and the TelegramConnection, and the
  # jti makes the token single-use (consumed once the alert is refined).
  module FeedbackToken
    PURPOSE = 'telegram:refine_alert'
    TTL = 15.minutes

    module_function

    # Stamps a fresh jti on the notification (invalidating any prior token) and
    # returns the URL-safe signed token string.
    def generate(notification, telegram_user_id:)
      jti = SecureRandom.urlsafe_base64(16)
      notification.update_columns( # rubocop:disable Rails/SkipsModelValidations
        refine_token_jti: jti, refine_token_consumed_at: nil, updated_at: Time.current
      )
      verifier.generate(
        { nid: notification.id, jaid: notification.job_alert_id, uid: telegram_user_id.to_i, jti: },
        expires_in: TTL, purpose: PURPOSE
      )
    end

    # @return [Hash, nil] symbol-keyed payload, or nil if tampered/expired/garbage
    def verify(token)
      return if token.blank?

      verifier.verify(token.to_s, purpose: PURPOSE).symbolize_keys
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end

    # Own verifier (url_safe so the token is safe in a query string) derived from
    # secret_key_base; never reuses another component's key.
    def verifier
      @verifier ||= ActiveSupport::MessageVerifier.new(
        Rails.application.key_generator.generate_key(PURPOSE),
        url_safe: true, serializer: JSON, digest: 'SHA256'
      )
    end
  end
end
