class TaskStatus < ApplicationRecord
  validates :task_id, presence: true, uniqueness: true
  validates :task_type, :status, presence: true

  # Status constants
  PENDING = 'pending'.freeze
  RUNNING = 'running'.freeze
  COMPLETED = 'completed'.freeze
  FAILED = 'failed'.freeze
  DISMISSED = 'dismissed'.freeze

  scope :active, -> { where(status: [PENDING, RUNNING]) }
  scope :recent_completed, -> { where(status: [COMPLETED, FAILED], updated_at: 1.hour.ago..Time.zone.now) }
  scope :not_dismissed, -> { where.not(status: DISMISSED) }

  def self.most_recent(type)
    where(status: [PENDING, RUNNING, COMPLETED, FAILED], task_type: type)
      .order(updated_at: :desc)
      .first
  end

  # Create a new task status record with a unique task_id
  def self.create_for_task(task_type, task_id = nil)
    task_id ||= SecureRandom.uuid
    create(
      task_id: task_id,
      task_type: task_type,
      status: PENDING,
      message: "#{task_type} task initialized"
    )
  end

  # Update the status and broadcast the change
  def update_status(status, message = nil)
    update({ status: status, message: message }.compact)
    broadcast_update
    self
  end

  def mark_running(message = 'Task is running')
    update_status(RUNNING, message)
  end

  def mark_completed(message = 'Task completed successfully')
    update_status(COMPLETED, message)
  end

  def mark_failed(message = 'Task failed')
    update_status(FAILED, message)
  end

  def delete_task
    present_task = find(id)
    destroy if present_task

    broadcast_update
  end

  def status_completed?
    status == COMPLETED
  end

  def status_failed?
    status == FAILED
  end

  def status_running?
    status == RUNNING
  end

  def status_pending?
    status == PENDING
  end

  def status_dismissed?
    status == DISMISSED
  end

  # Mark the task as dismissed
  def mark_dismissed
    update_status(DISMISSED, 'Task dismissed by user')
  end

  def self.delete_all_dismissed
    where(status: DISMISSED).find_each(&:destroy)
  end

  # Dismiss all completed or failed tasks
  def self.dismiss_all_except_current(type)
    # Keep only the most recent task if completed within the last hour or still running/pending
    most_recent_task = most_recent(type)
    most_recent_id = most_recent_task && most_recent_task.updated_at >= 1.hour.ago ? most_recent_task.id : nil

    # Dismiss all other completed or failed tasks
    tasks_to_dismiss = where(status: [COMPLETED, FAILED], task_type: type)
                       .where.not(id: most_recent_id)

    tasks_to_dismiss.find_each(&:mark_dismissed)
  end

  def self.delete_all
    find_each(&:destroy)
  end

  # Broadcast the task status update via ActionCable
  def broadcast_update
    data = {
      task_id: task_id,
      task_type: task_type,
      status: status,
      message: message,
      updated_at: updated_at,
      deleted: destroyed?
    }

    ActionCable.server.broadcast('task_status_channel', data)
  end
end
