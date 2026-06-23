# frozen_string_literal: true

class CreateJobAlertNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :job_alert_notifications do |t|
      t.references :job_alert, null: false, foreign_key: true
      t.references :job, null: false, foreign_key: true
      # Denormalised owner — lets us group pending notifications per user for digests
      # without joining through job_alerts.
      t.references :user, null: false, foreign_key: true

      t.float :match_score
      t.string :channel, null: false, default: 'telegram'
      t.integer :status, null: false, default: 0 # pending/sent/failed/skipped
      t.text :error
      t.datetime :sent_at

      t.timestamps
    end

    # The dedup guarantee: at most one notification per (alert, job) pair.
    add_index :job_alert_notifications, %i[job_alert_id job_id], unique: true
    add_index :job_alert_notifications, %i[user_id status]
  end
end
