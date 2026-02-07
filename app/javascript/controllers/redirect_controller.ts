import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLElement> {
  static values = {
    url: String,
    delay: { type: Number, default: 1000 }
  }

  declare urlValue: string
  declare delayValue: number

  private timeoutId: number | null = null

  connect(): void {
    // 自动跳转
    this.timeoutId = window.setTimeout(() => {
      window.location.href = this.urlValue
    }, this.delayValue)
  }

  disconnect(): void {
    if (this.timeoutId) {
      clearTimeout(this.timeoutId)
    }
  }
}
