import { Controller } from "@hotwired/stimulus"

/**
 * SDK Integration Controller
 *
 * Handles SDK availability detection and communication with external development tools
 *
 * Usage:
 *   <div data-controller="sdk-integration"
 *        data-sdk-integration-message-value="Help with this page"
 *        data-sdk-integration-action-value="sendMessage">
 *     <button data-sdk-integration-target="sdkButton"
 *             data-action="click->sdk-integration#sendToChatbox"
 *             style="display: none;">
 *       Ask AI
 *     </button>
 *   </div>
 *
 * Targets:
 *   - sdkButton (optional): Button shown only when SDK is available
 *
 * Values:
 *   - message (String): Message to send to SDK chatbox
 *   - action (String): SDK action type - "sendMessage" or "sendErrorForFix"
 *
 * Actions:
 *   - sendToChatbox: Send message to SDK chatbox
 *   - sendErrorToChatbox: Send error to SDK for fixing
 */

// stimulus-validator: system-controller
export default class extends Controller<HTMLElement> {
  static targets = [
    "sdkButton"
  ]

  static values = {
    message: String,
    action: String
  }

  // Declare targets and values
  declare readonly sdkButtonTarget: HTMLButtonElement
  declare readonly hasSdkButtonTarget: boolean
  declare readonly messageValue: string
  declare readonly actionValue: string

  connect(): void {
    // Check SDK availability and show SDK buttons if available
    this.checkSDKAvailability()
  }

  // Send message to chatbox (SDK integration)
  sendToChatbox(): void {
    if (!window.sdkUtils || !window.sdkUtils.sendMessage) {
      console.warn('SDK not available')
      return
    }

    const message = this.messageValue || this.generateDefaultMessage()
    window.sdkUtils.sendMessage(message)
  }

  // Send error to chatbox for fixing
  sendErrorToChatbox(): void {
    if (!window.sdkUtils || !window.sdkUtils.sendErrorForFix) {
      console.warn('SDK not available')
      return
    }

    const action = this.actionValue || 'sendErrorForFix'
    if (action === 'sendErrorForFix') {
      const errorMessage = this.messageValue || 'Unknown error'
      window.sdkUtils.sendErrorForFix({ errorMessage })
    } else {
      const message = this.messageValue || this.generateDefaultMessage()
      window.sdkUtils.sendMessage(message)
    }
  }

  // Check SDK availability and show/hide SDK buttons
  private checkSDKAvailability(): void {
    if (!this.hasSdkButtonTarget) return

    const checkAndShow = () => {
      if (window.isSDKAvailable && window.isSDKAvailable()) {
        this.sdkButtonTarget.style.display = 'block'
        return true
      }
      return false
    }

    // Initial check
    if (!checkAndShow()) {
      // Retry after 1 second (in case SDK is loading)
      setTimeout(checkAndShow, 1000)
      // Final retry after 2.8 seconds
      setTimeout(checkAndShow, 2800)
    }
  }

  // Generate default message for SDK
  private generateDefaultMessage(): string {
    const url = window.location.pathname.substring(1)
    return `Please help me with this page: ${url}

URL: ${window.location.href}
Path: ${url}

I need assistance with this page.`
  }
}
