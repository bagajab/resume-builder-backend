# frozen_string_literal: true

class CreateJobAlerts < ActiveRecord::Migration[8.1]
  def change
    create_table :job_alerts do |t|
      t.references :user, null: false, foreign_key: true

      t.string :name, null: false
      # Search criteria. Empty array = "any" (wildcard) for that dimension.
      t.string :titles, array: true, null: false, default: []
      t.string :keywords, array: true, null: false, default: []
      t.string :locations, array: true, null: false, default: []
      t.string :experience_levels, array: true, null: false, default: []
      t.string :employment_types, array: true, null: false, default: []
      t.string :remote_preference, null: false, default: 'any'

      # Optional salary floor/ceiling. Job#salary is free-text, so matching is best-effort.
      t.integer :salary_min
      t.integer :salary_max
      t.string :salary_currency

      t.integer :frequency, null: false, default: 0 # instant/daily/weekly
      t.integer :status, null: false, default: 0    # active/paused
      t.datetime :last_run_at

      t.timestamps
    end

    add_index :job_alerts, :status
    # GIN indexes back the SQL pre-filter in JobAlerts::ScanService.
    add_index :job_alerts, :keywords, using: :gin
    add_index :job_alerts, :titles, using: :gin
  end
end
