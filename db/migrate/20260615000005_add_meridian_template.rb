# frozen_string_literal: true

class AddMeridianTemplate < ActiveRecord::Migration[8.1]
  class MigrationTemplate < ActiveRecord::Base
    self.table_name = 'templates'
  end

  def up
    MigrationTemplate.find_or_create_by!(slug: 'meridian') do |template|
      template.name = 'Meridian'
      template.description = 'Two-column layout with a bold dark sidebar carrying the photo, achievements, education, skills and courses beside a light main column'
    end
  end

  def down
    MigrationTemplate.find_by(slug: 'meridian')&.destroy
  end
end
