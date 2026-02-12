import { Controller } from "@hotwired/stimulus"

/**
 * Stimulus controller: theme-sync
 * Handles theme synchronization confirmation dialog
 *
 * Targets: none
 * Values: none
 * Actions:
 *   - confirm: Show confirmation dialog and submit sync request
 */
export default class extends Controller {
  confirm(event: Event) {
    event.preventDefault()
    
    const confirmed = confirm(
      "确定要同步内置主题吗？\n\n" +
      "此操作会从主题文件重新读取并更新所有13个内置主题的CSS。\n\n" +
      "用户自定义主题不会受到影响。"
    )
    
    if (confirmed) {
      this.submitSync()
    }
  }
  
  private submitSync() {
    const form = document.createElement('form')
    form.method = 'POST'
    form.action = '/admin/themes/sync'
    
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    if (csrfToken) {
      const csrfInput = document.createElement('input')
      csrfInput.type = 'hidden'
      csrfInput.name = 'authenticity_token'
      csrfInput.value = csrfToken
      form.appendChild(csrfInput)
    }
    
    document.body.appendChild(form)
    form.submit()
  }
}
