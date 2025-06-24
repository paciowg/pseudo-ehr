import consumer from "./consumer"

consumer.subscriptions.create("TaskStatusChannel", {
  connected() {
    console.log("Connected to TaskStatusChannel", new Date().toISOString());
  },

  disconnected() {
    // Try to reconnect after a delay
    setTimeout(() => {
      consumer.connect();
    }, 3000);
  },

  received(data) {

    // Find or create the task status container
    let taskContainer = document.getElementById(`task-status-${data.task_id}`);

    if (!taskContainer) {
      // Create a new task status container if it doesn't exist
      const tasksContainer = document.getElementById('task-statuses');
      if (tasksContainer) {
        taskContainer = document.createElement('div');
        taskContainer.id = `task-status-${data.task_id}`;
        taskContainer.className = 'task-status-item mb-4 p-4 border rounded';
        tasksContainer.appendChild(taskContainer);
      }
    }

    if (taskContainer) {
      // Update the task status container with the new data
      let statusClass = '';
      switch (data.status) {
        case 'pending':
          statusClass = 'bg-yellow-100 border-yellow-300';
          break;
        case 'running':
          statusClass = 'bg-blue-100 border-blue-300';
          break;
        case 'completed':
          statusClass = 'bg-green-100 border-green-300';
          break;
        case 'failed':
          statusClass = 'bg-red-100 border-red-300';
          break;
        default:
          statusClass = 'bg-gray-100 border-gray-300';
      }

      // Remove old status classes and add the new one
      taskContainer.className = `task-status-item mb-4 p-4 border rounded ${statusClass}`;

      // Format the folder path for display
      const folderPath = data.folder_path.replace('sample_use_cases/', '');

      // Update the content
      taskContainer.innerHTML = `
        <div class="flex justify-between items-start">
          <div>
            <h3 class="font-semibold text-lg">${data.task_type}</h3>
            <p class="text-sm text-gray-600">
              <span class="font-medium">Folder:</span> ${folderPath}
            </p>
            <p class="text-sm text-gray-600">
              <span class="font-medium">Server:</span> ${data.server_url}
            </p>
          </div>
          <div class="text-right">
            <span class="inline-block px-2 py-1 text-xs font-semibold rounded ${statusClass}">
              ${data.status.toUpperCase()}
            </span>
          </div>
        </div>
        <div class="mt-2 text-sm">
          <p>${data.message}</p>
        </div>
        <div class="mt-1 text-xs text-gray-500">
          Last updated: ${new Date(data.updated_at).toLocaleString()}
        </div>
      `;

      // If the task is completed or failed, add a dismiss button
      if (data.status === 'completed' || data.status === 'failed') {
        const dismissButton = document.createElement('button');
        dismissButton.className = 'mt-2 px-2 py-1 text-xs bg-gray-200 hover:bg-gray-300 rounded';
        dismissButton.textContent = 'Dismiss';
        dismissButton.onclick = function () {
          // Send a request to mark the task as dismissed
          fetch(`/task_statuses/${data.task_id}/dismiss`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
            }
          }).then(() => {
            // Remove the task container from the DOM
            taskContainer.remove();
          });
        };
        taskContainer.appendChild(dismissButton);
      }
    }
  }
});
