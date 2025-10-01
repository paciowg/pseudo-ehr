import consumer from "channels/consumer"

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
    // This will be handled in Stimulus controller
    const event = new CustomEvent("task-status:update", { detail: data })
    window.dispatchEvent(event)
  }
});
