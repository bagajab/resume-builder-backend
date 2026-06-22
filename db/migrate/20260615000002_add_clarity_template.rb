# frozen_string_literal: true

class AddClarityTemplate < ActiveRecord::Migration[8.1]
  class MigrationTemplate < ActiveRecord::Base
    self.table_name = 'templates'
  end

  def up
    MigrationTemplate.find_or_create_by!(slug: 'clarity') do |template|
      template.name = 'Clarity'
      template.description = 'Airy two-column layout with an accent name header and dotted corner motif — summary, accent skill pills, experience and dotted languages alongside icon-led achievements, courses, education and interests'
    end
  end

  def down
    MigrationTemplate.find_by(slug: 'clarity')&.destroy
  end
end
