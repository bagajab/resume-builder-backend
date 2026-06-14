# frozen_string_literal: true

class AddPasswordSetToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :password_set, :boolean, default: false, null: false

    safety_assured do
      execute <<~SQL.squish
        UPDATE users SET password_set = TRUE WHERE provider = 'email'
      SQL
    end
  end

  def down
    remove_column :users, :password_set
  end
end
