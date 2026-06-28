# frozen_string_literal: true

# Renames the three Ethiopian sidebar templates to single-word display names:
#   Adwa Sentinel  -> Sentinel
#   Yegna Editorial -> Editorial
#   Gondar Crest    -> Crest
# Slugs are unchanged; only the user-facing Template#name is updated.
class RenameSidebarTemplates < ActiveRecord::Migration[8.1]
  class MigrationTemplate < ActiveRecord::Base
    self.table_name = 'templates'
  end

  RENAMES = {
    'adwa' => { new: 'Sentinel', old: ['Adwa Sentinel'] },
    'yegna' => { new: 'Editorial', old: ['Yegna Editorial'] },
    # 'Slate Modern' was an earlier name for this slug — cover it too.
    'gondar' => { new: 'Crest', old: ['Gondar Crest', 'Slate Modern'] }
  }.freeze

  def up
    RENAMES.each do |slug, names|
      MigrationTemplate.where(slug:).update_all(name: names[:new])
    end
  end

  def down
    RENAMES.each do |slug, names|
      MigrationTemplate.where(slug:).update_all(name: names[:old].first)
    end
  end
end
