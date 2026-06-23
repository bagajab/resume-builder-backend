# frozen_string_literal: true

# Links a user to their Telegram chat so the bot can deliver job alerts. Because
# Telegram bots cannot message arbitrary users, linking happens via a one-time
# deep-link token (t.me/<bot>?start=<token>): the bot resolves the token to this
# record and stores the chat_id. The phone is verified through Telegram's native
# "Share Contact" flow (see Telegram::UpdateProcessor).
class TelegramConnection < ApplicationRecord
  LINK_TOKEN_TTL = 30.minutes

  belongs_to :user

  enum :status, { pending: 0, linked: 1 }

  def self.generate_link_token
    SecureRandom.urlsafe_base64(24)
  end

  # Resets the connection to a pending state with a fresh, time-boxed token.
  def fresh_link_token!
    update!(
      status: :pending,
      link_token: self.class.generate_link_token,
      link_token_expires_at: LINK_TOKEN_TTL.from_now
    )
    link_token
  end

  def link_token_valid?
    link_token.present? && link_token_expires_at&.future?
  end

  def deep_link
    "https://t.me/#{Telegram.config.bot_username}?start=#{link_token}"
  end
end
