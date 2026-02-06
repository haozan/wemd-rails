import { Controller } from "@hotwired/stimulus"

// Navbar scroll controller for transparent navbar
// Automatically adds/removes classes based on scroll position
export default class extends Controller {
  connect() {
    this.element.classList.add('transition-all', 'duration-300')
    window.addEventListener('scroll', this.handleScroll)
    this.handleScroll()
  }

  disconnect() {
    window.removeEventListener('scroll', this.handleScroll)
  }

  handleScroll = () => {
    if (window.scrollY > 50) {
      this.element.classList.remove('bg-transparent')
      this.element.classList.add('bg-surface-elevated', 'shadow-md', 'border-b', 'border-border')
    } else {
      this.element.classList.add('bg-transparent')
      this.element.classList.remove('bg-surface-elevated', 'shadow-md', 'border-b', 'border-border')
    }
  }
}
