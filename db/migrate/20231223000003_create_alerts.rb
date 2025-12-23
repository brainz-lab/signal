class CreateAlerts < ActiveRecord::Migration[8.0]
  def change
    create_table :alerts, id: :uuid do |t|
      t.uuid :project_id, null: false
      t.references :alert_rule, type: :uuid, null: false, foreign_key: true

      # Identification (for grouping)
      t.string :fingerprint, null: false      # Hash of rule + labels
      t.jsonb :labels, default: {}            # Dimension values that triggered

      # State
      t.string :state, null: false            # pending, firing, resolved
      t.datetime :started_at, null: false
      t.datetime :resolved_at
      t.datetime :last_fired_at

      # Value that triggered
      t.float :current_value
      t.float :threshold_value

      # Notification tracking
      t.datetime :last_notified_at
      t.integer :notification_count, default: 0

      # Acknowledgment
      t.boolean :acknowledged, default: false
      t.datetime :acknowledged_at
      t.string :acknowledged_by
      t.text :acknowledgment_note

      # Incident link
      t.uuid :incident_id

      t.timestamps

      t.index [:project_id, :state]
      t.index [:alert_rule_id, :fingerprint], unique: true, where: "state != 'resolved'"
      t.index [:project_id, :started_at]
      t.index :fingerprint
      t.index :project_id
    end
  end
end
