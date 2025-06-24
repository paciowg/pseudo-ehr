class CreateTaskStatuses < ActiveRecord::Migration[7.2]
  def change
    create_table :task_statuses do |t|
      t.string :task_id
      t.string :task_type
      t.string :status
      t.text :message
      t.string :folder_path
      t.string :server_url

      t.timestamps
    end
  end
end
