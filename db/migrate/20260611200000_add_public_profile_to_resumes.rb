# frozen_string_literal: true

class AddPublicProfileToResumes < ActiveRecord::Migration[8.1]
  def change
    add_column :resumes, :public_slug, :string
    add_column :resumes, :public_profile_enabled, :boolean, null: false, default: false
    add_column :resumes, :published_at, :datetime

    safety_assured do
      add_index :resumes, :public_slug, unique: true, where: 'public_slug IS NOT NULL'
      add_index :resumes, :public_profile_enabled, where: 'public_profile_enabled = true'
    end
  end
end
