class AddUniqueIndexToTaskStatuses < ActiveRecord::Migration[7.2]
  def change
    add_index :task_statuses, :task_id, unique: true, if_not_exists: true
  end
end
