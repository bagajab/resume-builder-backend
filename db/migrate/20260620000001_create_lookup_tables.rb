# frozen_string_literal: true

class CreateLookupTables < ActiveRecord::Migration[8.1]
  # Lookup/taxonomy tables backing the resume editor dropdowns. They all share the
  # same column shape (see Lookups::Optionable); `skill_options` additionally
  # carries a `category`. Trigram (`pg_trgm`) GIN indexes make the option search
  # fast and fuzzy instead of a bare sequential ILIKE scan.
  TABLES = %w[
    countries cities job_titles industries degrees fields_of_study
    technologies languages language_proficiencies interests
  ].freeze

  def change
    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')

    TABLES.each { |table| create_lookup_table(table) }

    create_lookup_table('skill_options') do |t|
      t.string :category, null: false, default: 'technical'
    end
    # Skill names are only unique within a category (e.g. "Design" can be both a
    # soft skill and a tool), so the dedupe index spans both columns.
    add_index :skill_options, %i[normalized_value category], unique: true,
                                                             name: 'index_skill_options_on_normalized_value_and_category'
    add_index :skill_options, :category
  end

  private

  def create_lookup_table(name)
    create_table name do |t|
      t.string :value, null: false
      t.string :normalized_value, null: false
      t.string :status, null: false, default: 'approved'
      t.integer :usage_count, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.references :submitted_by_user, foreign_key: { to_table: :users }, null: true
      yield t if block_given?
      t.timestamps
    end

    # Skill_options dedupes on (normalized_value, category) instead — added above.
    add_index name, :normalized_value, unique: true unless name == 'skill_options'
    add_index name, :status
    add_index name, :value, using: :gin, opclass: :gin_trgm_ops,
                            name: "index_#{name}_on_value_trgm"
  end
end
