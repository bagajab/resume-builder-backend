# frozen_string_literal: true

class AddProfessionalTemplate < ActiveRecord::Migration[8.1]
  class MigrationTemplate < ActiveRecord::Base
    self.table_name = 'templates'
  end

  def up
    MigrationTemplate.find_or_create_by!(slug: 'professional') do |template|
      template.name = 'Professional'
      template.description = 'Two-column executive layout with accent headings and structured entries'
    end
  end

  def down
    MigrationTemplate.find_by(slug: 'professional')&.destroy
  end
end
