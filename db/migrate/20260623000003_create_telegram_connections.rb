# frozen_string_literal: true

class CreateTelegramConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :telegram_connections do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }

      t.integer :status, null: false, default: 0 # pending/linked
      # One-time deep-link token (t.me/<bot>?start=<token>) used to bind a Telegram
      # chat to this user before the chat_id is known.
      t.string :link_token
      t.datetime :link_token_expires_at

      t.bigint :telegram_chat_id
      t.bigint :telegram_user_id
      t.string :telegram_username

      # Verified via Telegram's "Share Contact" — Telegram itself proves ownership.
      t.string :phone_number
      t.boolean :phone_verified, null: false, default: false
      t.datetime :linked_at

      t.timestamps
    end

    add_index :telegram_connections, :link_token, unique: true
    add_index :telegram_connections, :telegram_chat_id
  end
end
