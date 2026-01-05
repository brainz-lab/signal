# frozen_string_literal: true

class AddSettingsToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :settings, :jsonb, default: {}, null: false
  end
end
