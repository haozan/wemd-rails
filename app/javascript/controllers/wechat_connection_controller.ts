import { Controller } from "@hotwired/stimulus"

type TestResponse = {
  ok?: boolean
  message?: string
}

/**
 * Tests the WeChat credentials and keeps the result visible before saving.
 *
 * A successful test waits a few seconds before submitting the parent form so
 * users can read the result instead of seeing it flash during the redirect.
 */
export default class extends Controller<HTMLFormElement> {
  static targets = ["appId", "appSecret", "button", "result"]
  static values = {
    url: String,
    autosaveDelay: { type: Number, default: 4000 },
  }

  declare readonly appIdTarget: HTMLInputElement
  declare readonly appSecretTarget: HTMLInputElement
  declare readonly buttonTarget: HTMLButtonElement
  declare readonly resultTarget: HTMLElement
  declare readonly urlValue: string
  declare readonly autosaveDelayValue: number

  private originalButtonHtml = ""
  private countdownTimer?: number
  private submitTimer?: number
  private autoSaving = false

  connect(): void {
    this.originalButtonHtml = this.buttonTarget.innerHTML
  }

  disconnect(): void {
    this.clearTimers()
  }

  async test(event: Event): Promise<void> {
    event.preventDefault()
    if (this.buttonTarget.disabled || this.autoSaving) return

    this.setBusy(true, "测试中…")
    this.showResult("正在连接微信，请稍候…", "pending")

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken(),
        },
        body: JSON.stringify({
          app_id: this.appIdTarget.value.trim(),
          app_secret: this.appSecretTarget.value.trim(),
        }),
      })
      const data = await response.json() as TestResponse

      if (data.ok) {
        this.beginAutoSave(data.message || "连接成功，配置正确。")
      } else {
        this.showResult(`✗ ${data.message || "连接失败，请检查配置。"}`, "error")
        this.restoreButton()
      }
    } catch (_error) {
      this.showResult("✗ 请求失败，请检查网络后重试。", "error")
      this.restoreButton()
    }
  }

  private beginAutoSave(message: string): void {
    this.autoSaving = true
    const delay = Math.max(this.autosaveDelayValue, 1000)
    let secondsLeft = Math.ceil(delay / 1000)

    this.setBusy(true, `测试通过，${secondsLeft} 秒后保存…`)
    this.showResult(`✓ ${message} ${secondsLeft} 秒后自动保存，你可以先确认结果。`, "success")

    this.countdownTimer = window.setInterval(() => {
      secondsLeft -= 1
      if (secondsLeft > 0) {
        this.setBusy(true, `测试通过，${secondsLeft} 秒后保存…`)
        this.showResult(`✓ ${message} ${secondsLeft} 秒后自动保存，你可以先确认结果。`, "success")
      }
    }, 1000)

    this.submitTimer = window.setTimeout(() => {
      this.clearTimers()
      this.setBusy(true, "保存中…")
      this.showResult(`✓ ${message} 正在保存配置…`, "success")
      this.element.submit()
    }, delay)
  }

  private setBusy(busy: boolean, label?: string): void {
    this.buttonTarget.disabled = busy
    if (label) this.buttonTarget.textContent = label
  }

  private restoreButton(): void {
    this.autoSaving = false
    this.buttonTarget.disabled = false
    this.buttonTarget.innerHTML = this.originalButtonHtml
  }

  private showResult(message: string, state: "pending" | "success" | "error"): void {
    this.resultTarget.textContent = message
    this.resultTarget.classList.remove("hidden", "text-secondary", "text-success", "text-destructive")
    this.resultTarget.classList.add({
      pending: "text-secondary",
      success: "text-success",
      error: "text-destructive",
    }[state])
  }

  private clearTimers(): void {
    if (this.countdownTimer) window.clearInterval(this.countdownTimer)
    if (this.submitTimer) window.clearTimeout(this.submitTimer)
    this.countdownTimer = undefined
    this.submitTimer = undefined
  }

  private csrfToken(): string {
    return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content || ""
  }
}
