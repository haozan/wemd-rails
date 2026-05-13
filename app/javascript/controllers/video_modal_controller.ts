import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="video-modal"
// Usage:
//   <button data-controller="video-modal"
//           data-video-modal-url-value="https://..."
//           data-video-modal-title-value="演示视频"
//           data-action="click->video-modal#open">▶</button>
export default class extends Controller {
  static values = { url: String, title: String }

  declare urlValue: string
  declare titleValue: string

  private overlay: HTMLDivElement | null = null
  private keyHandler = (e: KeyboardEvent) => {
    if (e.key === "Escape") this.close()
  }

  open(e: Event) {
    e.preventDefault()
    if (this.overlay) return

    const overlay = document.createElement("div")
    overlay.className =
      "fixed inset-0 z-[9999] flex items-center justify-center bg-black/80 backdrop-blur-sm"
    overlay.addEventListener("click", (ev) => {
      if (ev.target === overlay) this.close()
    })

    const box = document.createElement("div")
    box.className =
      "relative w-[90vw] max-w-4xl bg-black rounded-lg shadow-2xl overflow-hidden"
    box.style.maxHeight = "85vh"

    const header = document.createElement("div")
    header.className =
      "flex items-center justify-between px-4 py-2 bg-zinc-900 text-white text-sm"
    header.innerHTML = `<span>${this.escapeHtml(this.titleValue || "演示视频")}</span>`

    const closeBtn = document.createElement("button")
    closeBtn.type = "button"
    closeBtn.setAttribute("aria-label", "关闭")
    closeBtn.className = "ml-2 text-white/70 hover:text-white text-xl leading-none"
    closeBtn.innerHTML = "&times;"
    closeBtn.addEventListener("click", () => this.close())
    header.appendChild(closeBtn)

    const video = document.createElement("video")
    video.src = this.urlValue
    video.controls = true
    video.autoplay = true
    video.playsInline = true
    video.className = "block w-full h-auto bg-black"
    video.style.maxHeight = "calc(85vh - 36px)"

    box.appendChild(header)
    box.appendChild(video)
    overlay.appendChild(box)
    document.body.appendChild(overlay)
    document.body.style.overflow = "hidden"
    document.addEventListener("keydown", this.keyHandler)

    this.overlay = overlay
  }

  close() {
    if (!this.overlay) return
    const v = this.overlay.querySelector("video")
    if (v) {
      v.pause()
      v.src = ""
    }
    this.overlay.remove()
    this.overlay = null
    document.body.style.overflow = ""
    document.removeEventListener("keydown", this.keyHandler)
  }

  disconnect() {
    this.close()
  }

  private escapeHtml(s: string): string {
    return s
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
  }
}
