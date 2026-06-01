# frozen_string_literal: true

class AddLayoutToResumes < ActiveRecord::Migration[8.1]
  def change
    add_column :resumes, :template_id, :string, null: false, default: 'classic'
    add_column :resumes, :layout_config, :jsonb, null: false, default: {}
  end
end
