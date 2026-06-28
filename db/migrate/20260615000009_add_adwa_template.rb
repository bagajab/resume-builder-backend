# frozen_string_literal: true

class AddAdwaTemplate < ActiveRecord::Migration[8.1]
  class MigrationTemplate < ActiveRecord::Base
    self.table_name = 'templates'
  end

  def up
    MigrationTemplate.find_or_create_by!(slug: 'adwa') do |template|
      template.name = 'Sentinel'
      template.description = 'Two-column layout with a deep-navy sidebar carrying the photo, summary, gradient skill rows, dot-meter languages and awards beside a cream main column with gold pill headings, diamond bullets and a vertical timeline rail'
    end
  end

  def down
    MigrationTemplate.find_by(slug: 'adwa')&.destroy
  end
end
