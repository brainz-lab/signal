class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications, id: :uuid do |t|
      t.uuid :project_id, null: false
      t.references :alert, type: :uuid, foreign_key: true
      t.references :incident, type: :uuid, foreign_key: true
      t.references :notification_channel, type: :uuid, null: false, foreign_key: true

      t.string :notification_type, null: false  # alert_fired, alert_resolved, incident_triggered, etc.
      t.string :status, null: false             # pending, sent, failed, skipped

      t.jsonb :payload, default: {}             # What was sent
      t.jsonb :response, default: {}            # Response from channel

      t.text :error_message
      t.integer :retry_count, default: 0
      t.datetime :sent_at
      t.datetime :next_retry_at

      t.timestamps

      t.index [ :project_id, :created_at ]
      t.index [ :notification_channel_id, :status ]
      t.index [ :status, :next_retry_at ], where: "status = 'failed'"
      t.index :project_id
    end
  end
end
