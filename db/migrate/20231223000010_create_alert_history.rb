class CreateAlertHistory < ActiveRecord::Migration[8.0]
  def change
    create_table :alert_histories, id: :uuid do |t|
      t.uuid :project_id, null: false
      t.references :alert_rule, type: :uuid, null: false, foreign_key: true

      t.datetime :timestamp, null: false
      t.string :state, null: false            # ok, pending, firing
      t.float :value
      t.jsonb :labels, default: {}

      t.string :fingerprint

      t.index [ :project_id, :timestamp ]
      t.index [ :alert_rule_id, :timestamp ]
      t.index :project_id
    end
  end
end
