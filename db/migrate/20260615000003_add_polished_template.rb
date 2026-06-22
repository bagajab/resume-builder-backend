# frozen_string_literal: true

class AddPolishedTemplate < ActiveRecord::Migration[8.1]
  class MigrationTemplate < ActiveRecord::Base
    self.table_name = 'templates'
  end

  def up
    MigrationTemplate.find_or_create_by!(slug: 'polished') do |template|
      template.name = 'Polished'
      template.description = 'Executive two-column layout with a plain header, bold black section rules, comma-separated skills and bar-meter languages alongside achievements, education, courses and interests'
    end
  end

  def down
    MigrationTemplate.find_by(slug: 'polished')&.destroy
  end
end
