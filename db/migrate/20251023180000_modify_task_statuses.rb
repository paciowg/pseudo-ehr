# rubocop:disable Rails/BulkChangeTable
class ModifyTaskStatuses < ActiveRecord::Migration[7.2]
  def change
    remove_column :task_statuses, :folder_path, :string
    remove_column :task_statuses, :server_url, :string
  end
end
# rubocop:enable Rails/BulkChangeTable
