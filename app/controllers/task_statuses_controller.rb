class TaskStatusesController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:dismiss]
  skip_before_action :current_server, raise: false

  # POST /task_statuses/:task_id/dismiss
  def dismiss
    task = TaskStatus.find_by(task_id: params[:task_id])

    if task
      task.mark_dismissed
      render json: { success: true }
    else
      render json: { success: false, error: 'Task not found' }, status: :not_found
    end
  end
end
