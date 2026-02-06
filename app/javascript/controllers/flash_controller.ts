import { Controller } from "@hotwired/stimulus"
import { showToast } from "../toast"

/**
 * Flash Controller
 *
 * Displays toast notifications on controller connect
 * Note: Flash messages from Rails automatically use this controller
 *
 * Usage:
 *   <div data-controller="flash"
 *        data-flash-message-value="<%= flash[:notice] %>"
 *        data-flash-type-value="success">
 *   </div>
 *
 * Values:
 *   - message (String, required): Message text to display
 *   - type (String, required): Toast type - "success", "error", "warning", "info"
 *   - position (String, default: "top-center"): Position - "top-right", "top-center", "top-left"
 *   - duration (Number, default: 3000): Display duration in milliseconds
 */

// stimulus-validator: system-controller
export default class extends Controller {
  static values = {
    message: String,
    type: String,
    position: { type: String, default: 'top-center' },
    duration: { type: Number, default: 3000 }
  }

  declare readonly messageValue: string
  declare readonly typeValue: string
  declare readonly positionValue: 'top-right' | 'top-center' | 'top-left'
  declare readonly durationValue: number

  connect(): void {
    // Show toast when controller connects
    if (this.messageValue) {
      showToast(
        this.messageValue,
        this.typeValue as any,
        this.positionValue,
        this.durationValue
      )
    }
  }
}
