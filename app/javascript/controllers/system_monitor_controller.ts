import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"
import { StreamActions } from "@hotwired/turbo"

// Global singleton subscription (shared across all controller instances)
let globalSubscription: any = null

// Manages singleton ActionCable subscription for system_monitor stream
// Used with data-turbo-permanent to prevent duplicate subscriptions
// stimulus-validator: system-controller
export default class extends Controller {
  static values = {
    signedName: String
  }

  declare signedNameValue: string

  connect() {
    // Global singleton: only one subscription across entire app
    if (globalSubscription) {
      console.log('[SystemMonitor] Global subscription already exists, skipping')
      return
    }

    globalSubscription = consumer.subscriptions.create(
      {
        channel: "Turbo::StreamsChannel",
        signed_stream_name: this.signedNameValue
      },
      {
        received(data: string) {
          // Parse and execute turbo-stream actions
          if (data && typeof data === 'string') {
            const template = document.createElement('template')
            template.innerHTML = data.trim()
            const streamElement = template.content.firstElementChild as any

            if (streamElement && streamElement.tagName === 'TURBO-STREAM') {
              const actionName = streamElement.getAttribute('action')
              if (actionName && StreamActions[actionName]) {
                StreamActions[actionName].call(streamElement)
              }
            }
          }
        }
      }
    )

    console.log('[SystemMonitor] Global subscription created')
  }

  disconnect() {
    // Never disconnect the global subscription (data-turbo-permanent should prevent this anyway)
    console.log('[SystemMonitor] Controller disconnected, but keeping global subscription alive')
  }
}
