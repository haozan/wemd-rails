import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="inline-video"
// Renders a poster + big play button; on click, swaps to <video> and plays.
// Avoids loading the video file until the user actually wants to watch.
//
// Usage:
//   <div data-controller="inline-video"
//        data-inline-video-url-value="https://...mp4"
//        data-inline-video-poster-value="https://...jpg"   (optional)
//        class="...">
//     <button data-inline-video-target="trigger"
//             data-action="click->inline-video#play">▶</button>
//     <div data-inline-video-target="container" class="hidden"></div>
//   </div>
export default class extends Controller {
  static values = { url: String, poster: String }
  static targets = ["trigger", "container"]

  declare urlValue: string
  declare posterValue: string
  declare triggerTarget: HTMLElement
  declare containerTarget: HTMLElement

  play(e: Event) {
    e.preventDefault()

    const video = document.createElement("video")
    video.src = this.urlValue
    if (this.posterValue) video.poster = this.posterValue
    video.controls = true
    video.autoplay = true
    video.playsInline = true
    video.preload = "auto"
    video.className = "absolute inset-0 w-full h-full bg-black rounded-2xl"

    this.containerTarget.innerHTML = ""
    this.containerTarget.appendChild(video)
    this.containerTarget.classList.remove("hidden")
    this.triggerTarget.classList.add("hidden")
  }
}
