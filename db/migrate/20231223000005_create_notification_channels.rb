class CreateNotificationChannels < ActiveRecord::Migration[8.0]
  def change
    create_table :notification_channels, id: :uuid do |t|
      t.uuid :project_id, null: false

      t.string :name, null: false
      t.string :slug, null: false
      t.string :channel_type, null: false     # slack, pagerduty, email, webhook, discord, teams, opsgenie

      # Configuration (encrypted at application level)
      t.jsonb :config, default: {}

      # Testing & status
      t.boolean :verified, default: false
      t.datetime :last_tested_at
      t.string :last_test_status
      t.datetime :last_used_at
      t.integer :success_count, default: 0
      t.integer :failure_count, default: 0

      t.boolean :enabled, default: true

      t.timestamps

      t.index [ :project_id, :slug ], unique: true
      t.index [ :project_id, :channel_type ]
      t.index :project_id
    end
  end
end
