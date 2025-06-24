class TaskStatus < ApplicationRecord
  validates :task_id, presence: true, uniqueness: true
  validates :task_type, :status, presence: true

  # Status constants
  PENDING = 'pending'.freeze
  RUNNING = 'running'.freeze
  COMPLETED = 'completed'.freeze
  FAILED = 'failed'.freeze
  DISMISSED = 'dismissed'.freeze

  # Scopes
  scope :active, -> { where(status: [PENDING, RUNNING]) }
  scope :recent_completed, -> { where(status: [COMPLETED, FAILED], updated_at: 1.hour.ago..Time.zone.now) }
  scope :not_dismissed, -> { where.not(status: DISMISSED) }

  # Get the most recent task
  def self.most_recent
    where(status: [PENDING, RUNNING, COMPLETED, FAILED])
      .order(updated_at: :desc)
      .first
  end

  # Create a new task status record with a unique task_id
  def self.create_for_task(task_type, folder_path, server_url)
    task_id = SecureRandom.uuid
    create(
      task_id: task_id,
      task_type: task_type,
      status: PENDING,
      message: 'Task initialized',
      folder_path: folder_path,
      server_url: server_url
    )
  end

  # Update the status and broadcast the change
  def update_status(status, message = nil)
    update(status: status, message: message) if message
    update(status: status) unless message
    broadcast_update
    self
  end

  # Mark the task as running
  def mark_running(message = 'Task is running')
    update_status(RUNNING, message)
  end

  # Mark the task as completed
  def mark_completed(message = 'Task completed successfully')
    update_status(COMPLETED, message)
  end

  # Mark the task as failed
  def mark_failed(message = 'Task failed')
    update_status(FAILED, message)
  end

  # Mark the task as dismissed
  def mark_dismissed
    update_status(DISMISSED, 'Task dismissed by user')
  end

  # Dismiss all completed or failed tasks
  def self.dismiss_all_except_current
    # Keep only the most recent task
    most_recent_id = most_recent&.id

    # Dismiss all other completed or failed tasks
    tasks_to_dismiss = where(status: [COMPLETED, FAILED])
                       .where.not(id: most_recent_id)

    tasks_to_dismiss.find_each(&:mark_dismissed)
  end

  # Broadcast the task status update via ActionCable
  def broadcast_update
    data = {
      task_id: task_id,
      task_type: task_type,
      status: status,
      message: message,
      folder_path: folder_path,
      server_url: server_url,
      updated_at: updated_at
    }

    ActionCable.server.broadcast('task_status_channel', data)
  end
end
