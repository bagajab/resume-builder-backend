# frozen_string_literal: true

class AddDoubleColumnTemplate < ActiveRecord::Migration[8.1]
  class MigrationTemplate < ActiveRecord::Base
    self.table_name = 'templates'
  end

  def up
    MigrationTemplate.find_or_create_by!(slug: 'double') do |template|
      template.name = 'Double Column'
      template.description = 'Clean two-column layout with a contact header, photo, icon-badged achievements and interests, courses, skills and dotted language meters'
    end
  end

  def down
    MigrationTemplate.find_by(slug: 'double')&.destroy
  end
end
