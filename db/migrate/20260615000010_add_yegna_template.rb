# frozen_string_literal: true

class AddYegnaTemplate < ActiveRecord::Migration[8.1]
  class MigrationTemplate < ActiveRecord::Base
    self.table_name = 'templates'
  end

  def up
    MigrationTemplate.find_or_create_by!(slug: 'yegna') do |template|
      template.name = 'Yegna Editorial'
      template.description = 'Magazine-styled two-column layout with a deep-maroon serif sidebar carrying the photo, summary, comma-separated skills, languages and certifications beside a cream main column with ruled headings and dash bullets'
    end
  end

  def down
    MigrationTemplate.find_by(slug: 'yegna')&.destroy
  end
end
