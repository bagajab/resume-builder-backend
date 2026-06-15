# frozen_string_literal: true

class CreateJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :jobs do |t|
      # Provenance / identity
      t.string :source, null: false
      t.string :source_uid
      t.string :url, null: false
      t.string :apply_url

      # Core posting
      t.string :title, null: false
      t.string :company_name
      t.string :company_logo_url
      t.string :location
      t.string :region
      t.boolean :remote, null: false, default: false
      t.string :employment_type
      t.string :category
      t.string :experience_level
      t.string :education_level
      t.string :salary

      # Long-form content
      t.text :summary
      t.text :description

      t.string :tags, array: true, null: false, default: []

      # Dates
      t.date :posted_on
      t.date :deadline_on

      # Lifecycle / scraping bookkeeping
      t.boolean :active, null: false, default: true
      t.jsonb :metadata, null: false, default: {}
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false

      t.timestamps
    end

    add_index :jobs, :url, unique: true
    add_index :jobs, :source
    add_index :jobs, %i[source source_uid]
    add_index :jobs, :posted_on
    add_index :jobs, :deadline_on
    add_index :jobs, :active
    add_index :jobs, :tags, using: :gin
  end
end
