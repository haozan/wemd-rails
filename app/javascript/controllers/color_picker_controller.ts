import { Controller } from "@hotwired/stimulus"

/**
 * 编辑器工具栏的"配色方案"选择器
 *
 * 语义:每个方案是一对颜色 (primary + bold)
 *   - primary 用于链接/引用边框/标题点缀(StyleRenderer 的 {{PRIMARY}})
 *   - bold    用于 <strong> 重点加粗文字(StyleRenderer 的 {{BOLD}})
 *
 * 交互:
 *   - 点击工具栏按钮打开 popover
 *   - 卡片式列表,每张卡片展示 scheme 名称 + 两色预览
 *   - 点击 → 立即 PATCH 保存到 user.wx_primary_color / wx_bold_color
 *   - 点击外部自动关闭
 *   - 重置 → 传空值,后端清空两个字段,渲染回退到主题默认
 */
export default class extends Controller<HTMLElement> {
  static targets = [
    "panel",
    "primarySwatch",
    "boldSwatch",
    "schemeOption",
    "checkMark",
    "status"
  ]
  static values = {
    url: String,
    primary: String,
    bold: String
  }

  declare readonly panelTarget: HTMLElement
  declare readonly primarySwatchTarget: HTMLElement
  declare readonly boldSwatchTarget: HTMLElement
  declare readonly schemeOptionTargets: HTMLElement[]
  declare readonly checkMarkTargets: HTMLElement[]
  declare readonly statusTarget: HTMLElement
  declare readonly hasStatusTarget: boolean
  declare readonly urlValue: string
  declare readonly primaryValue: string
  declare readonly boldValue: string

  private _outsideHandler?: (e: MouseEvent) => void
  private _saveTimer?: number
  private _lastSaved: string = ""

  connect() {
    this._lastSaved = this._key(this.primaryValue, this.boldValue)
    this._refreshCheckMarks()
  }

  disconnect() {
    this._detachOutsideHandler()
  }

  toggle(e: Event) {
    e.preventDefault()
    e.stopPropagation()
    const hidden = this.panelTarget.classList.toggle("hidden")
    if (!hidden) {
      this._attachOutsideHandler()
    } else {
      this._detachOutsideHandler()
    }
  }

  close() {
    this.panelTarget.classList.add("hidden")
    this._detachOutsideHandler()
  }

  // 点击某个配色方案卡片
  setScheme(e: Event) {
    e.preventDefault()
    const btn = e.currentTarget as HTMLElement
    const primary = btn.dataset.primary || ""
    const bold    = btn.dataset.bold || ""
    const id      = btn.dataset.schemeId || ""
    if (!primary || !bold) return

    this._applySwatches(primary, bold)
    this._activeSchemeId = id
    this._refreshCheckMarks()
    this._save(primary, bold)
  }

  // 恢复默认(传空,后端存 null,渲染时走主题默认色)
  reset(e: Event) {
    e.preventDefault()
    // 视觉上回退到第一条方案(仅展示,不影响实际空值保存)
    const first = this.schemeOptionTargets[0]
    if (first) {
      const primary = first.dataset.primary || "#1e6bb8"
      const bold    = first.dataset.bold || "#d63200"
      this._applySwatches(primary, bold)
    }
    this._activeSchemeId = ""
    this._refreshCheckMarks()
    this._save("", "")
  }

  // ---- 内部辅助 ----

  private _activeSchemeId: string = ""

  private _applySwatches(primary: string, bold: string) {
    this.primarySwatchTarget.style.background = primary
    this.boldSwatchTarget.style.background = bold
    // 同步给 wemd_editor_controller 的 watcher(它用 primary swatch 的 background 检测变更)
  }

  private _refreshCheckMarks() {
    // 根据当前 primary+bold 找匹配的方案 id,显示 check
    const targetId = this._activeSchemeId || this._findSchemeIdByColors(
      this.primarySwatchTarget.style.background,
      this.boldSwatchTarget.style.background
    )
    this.checkMarkTargets.forEach((mark) => {
      const id = mark.dataset.schemeId
      if (id && id === targetId) {
        mark.classList.remove("hidden")
      } else {
        mark.classList.add("hidden")
      }
    })
  }

  private _findSchemeIdByColors(primaryBg: string, boldBg: string): string {
    // 通过 rgb(...) 规范化后比对 data-primary / data-bold
    const normP = this._rgbToHex(primaryBg)
    const normB = this._rgbToHex(boldBg)
    for (const opt of this.schemeOptionTargets) {
      if (
        opt.dataset.primary?.toLowerCase() === normP &&
        opt.dataset.bold?.toLowerCase() === normB
      ) {
        return opt.dataset.schemeId || ""
      }
    }
    return ""
  }

  private _rgbToHex(s: string): string {
    if (!s) return ""
    const m = s.match(/rgb\((\d+)[\s,]+(\d+)[\s,]+(\d+)/i)
    if (!m) return s.toLowerCase().trim()
    const toHex = (n: string) => parseInt(n, 10).toString(16).padStart(2, "0")
    return "#" + toHex(m[1]) + toHex(m[2]) + toHex(m[3])
  }

  private _attachOutsideHandler() {
    this._outsideHandler = (e: MouseEvent) => {
      if (!this.element.contains(e.target as Node)) {
        this.close()
      }
    }
    requestAnimationFrame(() => {
      if (this._outsideHandler) {
        document.addEventListener("click", this._outsideHandler)
      }
    })
  }

  private _detachOutsideHandler() {
    if (this._outsideHandler) {
      document.removeEventListener("click", this._outsideHandler)
      this._outsideHandler = undefined
    }
  }

  private _key(p: string, b: string): string {
    return `${(p || "").toLowerCase()}|${(b || "").toLowerCase()}`
  }

  // 防抖保存
  private _save(primary: string, bold: string) {
    const key = this._key(primary, bold)
    if (key === this._lastSaved) return

    if (this._saveTimer) {
      window.clearTimeout(this._saveTimer)
    }
    this._saveTimer = window.setTimeout(() => this._doSave(primary, bold, key), 200)
  }

  private async _doSave(primary: string, bold: string, key: string) {
    if (!this.urlValue) return
    try {
      const res = await fetch(this.urlValue, {
        method: "PATCH",
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this._csrfToken(),
        },
        body: JSON.stringify({ primary_color: primary, bold_color: bold }),
      })
      if (res.ok) {
        this._lastSaved = key
        this._flash("已保存", false)
        // 通知编辑器:配色方案变了,微信预览需要重新渲染
        window.dispatchEvent(new CustomEvent("wemd:color-scheme-changed", {
          detail: { primary, bold }
        }))
      } else {
        const data = await res.json().catch(() => ({}))
        this._flash(data.error || "保存失败", true)
      }
    } catch (err) {
      this._flash("网络错误", true)
    }
  }

  private _flash(msg: string, isError: boolean) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = msg
    this.statusTarget.classList.remove("hidden", "text-destructive", "text-green-600")
    this.statusTarget.classList.add(isError ? "text-destructive" : "text-green-600")
    window.setTimeout(() => {
      this.statusTarget.classList.add("hidden")
    }, 1500)
  }

  private _csrfToken(): string {
    const el = document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement | null
    return el?.content || ""
  }
}
