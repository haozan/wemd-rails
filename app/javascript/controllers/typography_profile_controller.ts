import { Controller } from "@hotwired/stimulus"

/** 持久化公众号排版档位，并通知编辑器刷新真实预览。 */
export default class extends Controller<HTMLElement> {
  static targets = ["select", "status"]
  static values = { url: String }

  declare readonly selectTarget: HTMLSelectElement
  declare readonly statusTarget: HTMLElement
  declare readonly hasStatusTarget: boolean
  declare readonly urlValue: string

  private lastSaved = ""

  connect(): void {
    this.lastSaved = this.selectTarget.value
  }

  async save(): Promise<void> {
    const nextProfile = this.selectTarget.value
    if (!this.urlValue || nextProfile === this.lastSaved) return

    this.selectTarget.disabled = true
    this.showStatus("保存中…", false)

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken(),
        },
        body: JSON.stringify({ typography_profile: nextProfile }),
      })
      const data = await response.json().catch(() => ({}))

      if (!response.ok || !data.ok) {
        this.selectTarget.value = this.lastSaved
        this.showStatus(data.error || "保存失败", true)
        return
      }

      this.lastSaved = nextProfile
      this.showStatus("已保存", false)
      window.dispatchEvent(new CustomEvent("wemd:typography-profile-changed", {
        detail: data.effective_typography,
      }))
    } catch (_error) {
      this.selectTarget.value = this.lastSaved
      this.showStatus("网络错误", true)
    } finally {
      this.selectTarget.disabled = false
    }
  }

  private showStatus(message: string, isError: boolean): void {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = message
    this.statusTarget.classList.remove("hidden", "text-destructive", "text-green-600")
    this.statusTarget.classList.add(isError ? "text-destructive" : "text-green-600")
    window.setTimeout(() => this.statusTarget.classList.add("hidden"), 1500)
  }

  private csrfToken(): string {
    const element = document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement | null
    return element?.content || ""
  }
}
