# frozen_string_literal: true

class AddCrispTemplate < ActiveRecord::Migration[8.1]
  class MigrationTemplate < ActiveRecord::Base
    self.table_name = 'templates'
  end

  def up
    MigrationTemplate.find_or_create_by!(slug: 'crisp') do |template|
      template.name = 'Crisp'
      template.description = 'Bold full-width accent banner header with a two-column body — summary, experience, education and dotted languages alongside icon-led achievements, underlined skills, courses and interests'
    end
  end

  def down
    MigrationTemplate.find_by(slug: 'crisp')&.destroy
  end
end
