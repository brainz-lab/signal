class CreateIncidents < ActiveRecord::Migration[8.0]
  def change
    create_table :incidents, id: :uuid do |t|
      t.uuid :project_id, null: false

      t.string :title, null: false
      t.text :summary
      t.string :severity, null: false         # info, warning, critical
      t.string :status, null: false           # triggered, acknowledged, resolved

      t.datetime :triggered_at, null: false
      t.datetime :acknowledged_at
      t.datetime :resolved_at

      t.string :acknowledged_by
      t.string :resolved_by
      t.text :resolution_note

      # Timeline of events
      t.jsonb :timeline, default: []

      # Affected services/components
      t.jsonb :affected_services, default: []

      # External links
      t.string :external_id                   # PagerDuty incident ID, etc.
      t.string :external_url

      t.timestamps

      t.index [:project_id, :status]
      t.index [:project_id, :triggered_at]
      t.index [:project_id, :severity]
      t.index :project_id
    end

    # Add foreign key from alerts to incidents
    add_foreign_key :alerts, :incidents, column: :incident_id
  end
end
