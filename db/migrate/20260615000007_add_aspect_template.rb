# frozen_string_literal: true

class AddAspectTemplate < ActiveRecord::Migration[8.1]
  class MigrationTemplate < ActiveRecord::Base
    self.table_name = 'templates'
  end

  def up
    MigrationTemplate.find_or_create_by!(slug: 'aspect') do |template|
      template.name = 'Aspect'
      template.description = 'Two-column layout with a light sidebar carrying the photo, achievements, education, skills, courses and interests beside the main experience column'
    end
  end

  def down
    MigrationTemplate.find_by(slug: 'aspect')&.destroy
  end
end
