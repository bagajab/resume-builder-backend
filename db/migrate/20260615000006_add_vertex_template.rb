# frozen_string_literal: true

class AddVertexTemplate < ActiveRecord::Migration[8.1]
  class MigrationTemplate < ActiveRecord::Base
    self.table_name = 'templates'
  end

  def up
    MigrationTemplate.find_or_create_by!(slug: 'vertex') do |template|
      template.name = 'Vertex'
      template.description = 'Single-column layout with heavy section rules, a blue accent, a two-column achievements grid, bar-meter languages and comma-separated core competencies'
    end
  end

  def down
    MigrationTemplate.find_by(slug: 'vertex')&.destroy
  end
end
