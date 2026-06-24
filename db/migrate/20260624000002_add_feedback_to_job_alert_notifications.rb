# frozen_string_literal: true

# Records interactive feedback a user gives on a delivered match (👍/👎 inline
# buttons) and the bookkeeping needed to drive the follow-up "refine alert" Mini
# App: the Telegram message id (so we can edit its keyboard) and a single-use
# refine-token id (consumed once the alert is refined). All nullable — existing
# rows are untouched.
class AddFeedbackToJobAlertNotifications < ActiveRecord::Migration[8.1]
  def change
    # All nullable additions to a modestly-sized table; safe. Strong Migrations
    # can't introspect a bulk change_table, so assert safety explicitly.
    safety_assured do
      change_table :job_alert_notifications, bulk: true do |t|
        t.string :feedback                  # "positive" | "negative"
        t.datetime :feedback_at
        t.bigint :telegram_message_id       # the delivered message, for keyboard edits
        t.string :refine_token_jti          # id of the current valid refine token (nil = none)
        t.datetime :refine_token_consumed_at # set once the refine token is used (single-use)
      end
    end
  end
end
