class CreateMaintenanceWindows < ActiveRecord::Migration[8.0]
  def change
    create_table :maintenance_windows, id: :uuid do |t|
      t.uuid :project_id, null: false

      t.string :name, null: false
      t.text :description

      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false

      # Scope: which rules to mute
      t.jsonb :rule_ids, default: []          # Empty = all rules
      t.jsonb :services, default: []          # Filter by service label

      # Recurrence
      t.boolean :recurring, default: false
      t.string :recurrence_rule              # RRULE format

      t.string :created_by
      t.boolean :active, default: true

      t.timestamps

      t.index [ :project_id, :starts_at, :ends_at ]
      t.index [ :project_id, :active ]
      t.index :project_id
    end
  end
end
