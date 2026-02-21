class CreateSavedSearches < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_searches, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :project_id, null: false
      t.string :name, null: false
      t.jsonb :query_params, default: {}, null: false
      t.timestamps
    end

    add_index :saved_searches, :project_id
    add_index :saved_searches, [:project_id, :name], unique: true
  end
end
