class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects, id: :uuid do |t|
      t.uuid :platform_project_id, null: false
      t.string :name
      t.string :environment, default: 'live'

      t.timestamps
    end

    add_index :projects, :platform_project_id, unique: true
  end
end
