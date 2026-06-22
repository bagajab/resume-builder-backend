# frozen_string_literal: true

class AddTimelineTemplate < ActiveRecord::Migration[8.1]
  class MigrationTemplate < ActiveRecord::Base
    self.table_name = 'templates'
  end

  def up
    MigrationTemplate.find_or_create_by!(slug: 'timeline') do |template|
      template.name = 'Timeline'
      template.description = 'Single-column layout with a vertical timeline rail for experience and education, underlined skill chips and progress-bar languages'
    end
  end

  def down
    MigrationTemplate.find_by(slug: 'timeline')&.destroy
  end
end
