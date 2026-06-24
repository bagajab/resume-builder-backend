# frozen_string_literal: true

# Adds the AI-enrichment layer to jobs: normalized, alert-ready columns populated
# by Jobs::Enricher (Gemini), plus the bookkeeping (content hash + status) that
# lets Jobs::ScraperService skip re-enriching jobs whose source content is
# unchanged. Source-scraped columns (title, description, salary, …) are left as-is;
# the AI writes to the new `ai_*`/structured columns so the original is preserved.
class AddAiEnrichmentToJobs < ActiveRecord::Migration[8.1]
  def change
    # jobs is a small, append-mostly scraping cache; adding nullable/defaulted
    # columns and indexing it is safe. Strong Migrations can't introspect a bulk
    # change_table, so assert safety explicitly.
    safety_assured do
      add_enrichment_columns
      add_enrichment_indexes
    end
  end

  private

  def add_enrichment_columns
    change_table :jobs, bulk: true do |t|
      # AI-generated text (kept separate from the scraped summary/description).
      t.text :ai_summary
      t.text :ai_description
      t.text :application_instructions

      # Normalized scalar facets for hard filters / display.
      t.string :seniority
      t.string :remote_type
      t.integer :salary_min
      t.integer :salary_max
      t.string :salary_currency
      t.string :salary_period
      t.integer :experience_years_min

      # Structured, matchable arrays.
      t.string :skills, array: true, null: false, default: []
      t.string :preferred_skills, array: true, null: false, default: []
      t.string :languages, array: true, null: false, default: []
      t.string :benefits, array: true, null: false, default: []
      t.text :responsibilities, array: true, null: false, default: []
      t.text :qualifications, array: true, null: false, default: []

      # Enrichment bookkeeping. content_hash is a digest of the source content we
      # last enriched from; a mismatch on the next scrape triggers re-enrichment.
      t.string :content_hash
      t.datetime :enriched_at
      t.string :enrichment_model
      t.integer :enrichment_version
      t.string :enrichment_status, null: false, default: 'pending'
    end
  end

  def add_enrichment_indexes
    add_index :jobs, :enrichment_status
    add_index :jobs, :content_hash
    add_index :jobs, :seniority
    add_index :jobs, :remote_type
    add_index :jobs, :skills, using: :gin
    add_index :jobs, :languages, using: :gin
  end
end
