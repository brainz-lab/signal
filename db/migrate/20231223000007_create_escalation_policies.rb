class CreateEscalationPolicies < ActiveRecord::Migration[8.0]
  def change
    create_table :escalation_policies, id: :uuid do |t|
      t.uuid :project_id, null: false

      t.string :name, null: false
      t.string :slug, null: false
      t.text :description

      # Escalation steps
      t.jsonb :steps, default: []

      # Repeat behavior
      t.boolean :repeat, default: false
      t.integer :repeat_after_minutes
      t.integer :max_repeats

      t.boolean :enabled, default: true

      t.timestamps

      t.index [:project_id, :slug], unique: true
      t.index :project_id
    end

    # Add foreign key from alert_rules to escalation_policies
    add_foreign_key :alert_rules, :escalation_policies, column: :escalation_policy_id
  end
end
