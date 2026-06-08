# frozen_string_literal: true

class AddSpotlightTemplate < ActiveRecord::Migration[8.1]
  class MigrationTemplate < ActiveRecord::Base
    self.table_name = 'templates'
  end

  def up
    MigrationTemplate.find_or_create_by!(slug: 'spotlight') do |template|
      template.name = 'Spotlight'
      template.description = 'Two-column layout with a bold indigo sidebar, skill meters, language rings and section badges'
    end
  end

  def down
    MigrationTemplate.find_by(slug: 'spotlight')&.destroy
  end
end
