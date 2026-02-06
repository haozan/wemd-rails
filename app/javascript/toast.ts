function createToastContainer(position: 'top-right' | 'top-center' | 'top-left' = 'top-right'): HTMLElement {
  const containerId = `toast-container-${position}`
  let container = document.getElementById(containerId)
  if (!container) {
    container = document.createElement('div')
    container.id = containerId

    const positionClasses = {
      'top-right': 'fixed top-3 right-4 z-[9999] flex flex-col gap-2 pointer-events-none',
      'top-center': 'fixed top-3 left-1/2 -translate-x-1/2 z-[9999] flex flex-col gap-2 pointer-events-none',
      'top-left': 'fixed top-3 left-4 z-[9999] flex flex-col gap-2 pointer-events-none'
    }

    container.className = positionClasses[position]
    document.body.appendChild(container)
  }
  return container
}

function showToast(
  message: string,
  type: 'success' | 'error' | 'info' | 'warning' | 'danger' = 'info',
  position: 'top-right' | 'top-center' | 'top-left' = 'top-right',
  duration: number = 3000 // 0 means no auto-close
): void {
  const container = createToastContainer(position)

  // Normalize type (danger -> error for alert styling)
  const alertType = (type === 'error' || type === 'danger') ? 'danger' : type

  const toastElement = document.createElement('div')
  toastElement.className = `alert-${alertType} pointer-events-auto max-w-md shadow-lg transform transition-all duration-300 ease-out translate-x-0 opacity-100 !py-2 !px-3`

  toastElement.innerHTML = `
    <div class="flex items-center gap-2">
      <span class="flex-1">${message}</span>
      <button class="p-0.5 -mr-1 rounded hover:bg-black/10 transition-colors" aria-label="Close">
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
        </svg>
      </button>
    </div>
  `

  const closeButton = toastElement.querySelector('button')
  closeButton?.addEventListener('click', () => {
    removeToast(toastElement, position)
  })

  const animations = {
    'top-right': { enter: 'translateX(400px)', exit: 'translateX(400px)' },
    'top-center': { enter: 'translateY(-20px)', exit: 'translateY(-20px)' },
    'top-left': { enter: 'translateX(-400px)', exit: 'translateX(-400px)' }
  }

  toastElement.style.transform = animations[position].enter
  toastElement.style.opacity = '0'
  container.appendChild(toastElement)

  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      toastElement.style.transform = 'translateY(0) translateX(0)'
      toastElement.style.opacity = '1'
    })
  })

  // Auto-close after duration (if duration > 0)
  if (duration > 0) {
    setTimeout(() => {
      removeToast(toastElement, position)
    }, duration)
  }
}

function removeToast(toast: HTMLElement, position: 'top-right' | 'top-center' | 'top-left' = 'top-right'): void {
  const animations = {
    'top-right': 'translateX(400px)',
    'top-center': 'translateY(-20px)',
    'top-left': 'translateX(-400px)'
  }

  toast.style.transform = animations[position]
  toast.style.opacity = '0'

  setTimeout(() => {
    toast.remove()

    const containerId = `toast-container-${position}`
    const container = document.getElementById(containerId)
    if (container && container.children.length === 0) {
      container.remove()
    }
  }, 300)
}

export { showToast }
