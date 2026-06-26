# frozen_string_literal: true

# Removes the four generic single-column templates (classic, modern, minimal,
# professional). Any resume still pointing at one is reassigned to the new
# default (spotlight) first so the not-null template_id foreign key stays valid,
# then the template rows are deleted.
class RemoveGenericTemplates < ActiveRecord::Migration[8.1]
  REMOVED_SLUGS = %w[classic modern minimal professional].freeze
  FALLBACK_SLUG = 'spotlight'

  class MigrationTemplate < ActiveRecord::Base
    self.table_name = 'templates'
  end

  class MigrationResume < ActiveRecord::Base
    self.table_name = 'resumes'
  end

  def up
    removed = MigrationTemplate.where(slug: REMOVED_SLUGS)
    return if removed.empty?

    fallback = MigrationTemplate.find_by(slug: FALLBACK_SLUG)
    raise "Cannot remove templates: fallback '#{FALLBACK_SLUG}' is missing" unless fallback

    MigrationResume.where(template_id: removed.select(:id)).update_all(template_id: fallback.id)
    removed.delete_all
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
