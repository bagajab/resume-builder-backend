# frozen_string_literal: true

class AddMeterFieldsToSkills < ActiveRecord::Migration[8.1]
  def change
    add_column :skills, :level, :integer
    add_column :skills, :color, :string
  end
end
