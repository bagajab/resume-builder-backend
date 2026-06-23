# frozen_string_literal: true

class AddGondarTemplate < ActiveRecord::Migration[8.1]
  class MigrationTemplate < ActiveRecord::Base
    self.table_name = 'templates'
  end

  def up
    MigrationTemplate.find_or_create_by!(slug: 'gondar') do |template|
      template.name = 'Gondar Crest'
      template.description = 'Royal-blue sidebar (no photo) with gold accents and dotted-underline headings carrying summary, two-column skill and language grids and certifications beside a white main column with a geometric crest motif'
    end
  end

  def down
    MigrationTemplate.find_by(slug: 'gondar')&.destroy
  end
end
