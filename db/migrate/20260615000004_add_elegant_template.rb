# frozen_string_literal: true

class AddElegantTemplate < ActiveRecord::Migration[8.1]
  class MigrationTemplate < ActiveRecord::Base
    self.table_name = 'templates'
  end

  def up
    MigrationTemplate.find_or_create_by!(slug: 'elegant') do |template|
      template.name = 'Elegant'
      template.description = 'Refined single-column layout with centered serif headings, a monochrome palette and a three-column key achievements grid'
    end
  end

  def down
    MigrationTemplate.find_by(slug: 'elegant')&.destroy
  end
end
