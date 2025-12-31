class CreateOnCallSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :on_call_schedules, id: :uuid do |t|
      t.uuid :project_id, null: false

      t.string :name, null: false
      t.string :slug, null: false
      t.string :timezone, default: 'UTC'

      # Schedule type
      t.string :schedule_type, null: false    # weekly, custom

      # For weekly rotation
      t.jsonb :weekly_schedule, default: {}

      # Rotation members
      t.jsonb :members, default: []           # List of user emails
      t.string :rotation_type                 # daily, weekly
      t.datetime :rotation_start              # When rotation started

      # Current on-call
      t.string :current_on_call
      t.datetime :current_shift_start
      t.datetime :current_shift_end

      t.boolean :enabled, default: true

      t.timestamps

      t.index [ :project_id, :slug ], unique: true
      t.index :project_id
    end
  end
end
