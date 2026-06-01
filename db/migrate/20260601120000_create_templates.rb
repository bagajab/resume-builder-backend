# frozen_string_literal: true

class CreateTemplates < ActiveRecord::Migration[8.1]
  TEMPLATES = [
    { name: 'Classic', slug: 'classic', description: 'Traditional single-column layout with centered header' },
    { name: 'Modern', slug: 'modern', description: 'Contemporary design with accent color bar' },
    { name: 'Minimal', slug: 'minimal', description: 'Clean, whitespace-focused layout with subtle typography' }
  ].freeze

  SLUG_ALIASES = {
    'sidebar' => 'minimal',
    'grid' => 'modern'
  }.freeze

  class MigrationTemplate < ActiveRecord::Base
    self.table_name = 'templates'
  end

  class MigrationResume < ActiveRecord::Base
    self.table_name = 'resumes'
  end

  def up
    create_table :templates do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.timestamps
    end

    add_index :templates, :slug, unique: true

    TEMPLATES.each { |attrs| MigrationTemplate.create!(attrs) }

    safety_assured do
      rename_column :resumes, :template_id, :template_slug
      add_reference :resumes, :template, foreign_key: true

      templates_by_slug = MigrationTemplate.all.index_by(&:slug)

      MigrationResume.find_each do |resume|
        slug = SLUG_ALIASES.fetch(resume.template_slug, resume.template_slug)
        template = templates_by_slug[slug] || templates_by_slug['classic']
        resume.update_column(:template_id, template.id)
      end

      change_column_null :resumes, :template_id, false
      remove_column :resumes, :template_slug
    end
  end

  def down
    safety_assured do
      add_column :resumes, :template_slug, :string, null: false, default: 'classic'

      templates_by_id = MigrationTemplate.all.index_by(&:id)

      MigrationResume.find_each do |resume|
        resume.update_column(:template_slug, templates_by_id[resume.template_id]&.slug || 'classic')
      end

      remove_reference :resumes, :template, foreign_key: true
      rename_column :resumes, :template_slug, :template_id
      drop_table :templates
    end
  end
end
