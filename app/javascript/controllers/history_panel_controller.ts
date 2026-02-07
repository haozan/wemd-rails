import { Controller } from "@hotwired/stimulus"

interface HistoryEntry {
  id: string
  title: string
  content: string
  saved_at: string
  theme_id: number | null
  theme?: {
    id: number
    name: string
    css?: string
  }
}

export default class extends Controller<HTMLElement> {
  static targets = [
    "sidebar",
    "list",
    "searchInput",
    "emptyState",
    "loadingState"
  ]

  static values = {
    currentDocumentId: String
  }

  declare readonly sidebarTarget: HTMLElement
  declare readonly listTarget: HTMLElement
  declare readonly searchInputTarget: HTMLInputElement
  declare readonly emptyStateTarget: HTMLElement
  declare readonly loadingStateTarget: HTMLElement
  declare readonly currentDocumentIdValue: string

  private history: HistoryEntry[] = []
  private filteredHistory: HistoryEntry[] = []
  private isOpen: boolean = false

  connect(): void {
    console.log("[HistoryPanel] connected")
    this.loadHistory()
  }

  disconnect(): void {
    console.log("[HistoryPanel] disconnected")
  }

  // 切换侧边栏显示/隐藏
  toggle(): void {
    this.isOpen = !this.isOpen
    
    if (this.isOpen) {
      this.sidebarTarget.classList.remove("-translate-x-full")
      this.sidebarTarget.classList.add("translate-x-0")
    } else {
      this.sidebarTarget.classList.remove("translate-x-0")
      this.sidebarTarget.classList.add("-translate-x-full")
    }
  }

  // 关闭侧边栏
  close(): void {
    if (this.isOpen) {
      this.toggle()
    }
  }

  // 加载历史记录
  // turbo-architecture-validation: disable
  async loadHistory(): Promise<void> {
    try {
      this.showLoading()
      
      const response = await fetch('/documents.json')
      if (!response.ok) throw new Error('Failed to load history')
      
      this.history = await response.json()
      this.filteredHistory = this.history
      this.renderHistory()
    } catch (error) {
      console.error('[HistoryPanel] Load failed:', error)
      this.showError()
    }
  }

  // 搜索过滤
  search(): void {
    const keyword = this.searchInputTarget.value.trim().toLowerCase()
    
    if (!keyword) {
      this.filteredHistory = this.history
    } else {
      this.filteredHistory = this.history.filter(entry => 
        (entry.title || '未命名文章').toLowerCase().includes(keyword)
      )
    }
    
    this.renderHistory()
  }

  // 恢复历史记录
  // turbo-architecture-validation: disable
  async restore(event: Event): Promise<void> {
    event.preventDefault()
    const button = event.currentTarget as HTMLElement
    const documentId = button.dataset.documentId
    
    if (!documentId) return
    
    try {
      const response = await fetch(`/documents/${documentId}/restore.json`)
      if (!response.ok) throw new Error('Failed to restore')
      
      const data = await response.json()
      if (data.success && data.document) {
        this.applyDocument(data.document)
        this.close()
        // Toast will be shown by wemd_editor_controller when it handles the history:restore event
      }
    } catch (error) {
      console.error('[HistoryPanel] Restore failed:', error)
      this.showToast('恢复失败,请重试', 'error')
    }
  }

  // 删除历史记录
  // turbo-architecture-validation: disable
  async delete(event: Event): Promise<void> {
    event.preventDefault()
    event.stopPropagation()
    
    const button = event.currentTarget as HTMLElement
    const documentId = button.dataset.documentId
    
    if (!documentId) return
    
    try {
      const response = await fetch(`/documents/${documentId}.json`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': this.getCsrfToken(),
          'Content-Type': 'application/json'
        }
      })
      
      if (!response.ok) {
        // 尝试解析服务器返回的错误消息
        const data = await response.json()
        const errorMessage = data.error || '删除失败,请重试'
        throw new Error(errorMessage)
      }
      
      // 从列表中移除
      this.history = this.history.filter(entry => entry.id !== documentId)
      this.filteredHistory = this.filteredHistory.filter(entry => entry.id !== documentId)
      this.renderHistory()
      this.showToast('已删除')
    } catch (error) {
      console.error('[HistoryPanel] Delete failed:', error)
      const errorMessage = error instanceof Error ? error.message : '删除失败,请重试'
      this.showToast(errorMessage, 'error')
    }
  }

  // 清空所有历史
  // turbo-architecture-validation: disable
  async clearAll(): Promise<void> {
    try {
      const response = await fetch('/documents/clear_history.json', {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': this.getCsrfToken(),
          'Content-Type': 'application/json'
        }
      })
      
      if (!response.ok) throw new Error('Failed to clear')
      
      this.history = []
      this.filteredHistory = []
      this.renderHistory()
      this.showToast('历史记录已清空')
    } catch (error) {
      console.error('[HistoryPanel] Clear failed:', error)
      this.showToast('清空失败,请重试', 'error')
    }
  }

  // 新建文章
  async createNew(): Promise<void> {
    window.location.href = '/documents/new'
  }

  // 私有方法

  private renderHistory(): void {
    this.loadingStateTarget.classList.add('hidden')
    
    if (this.filteredHistory.length === 0) {
      this.listTarget.classList.add('hidden')
      this.emptyStateTarget.classList.remove('hidden')
    } else {
      this.listTarget.classList.remove('hidden')
      this.emptyStateTarget.classList.add('hidden')
      
      this.listTarget.innerHTML = this.filteredHistory.map(entry => this.renderEntry(entry)).join('')
    }
  }

  private renderEntry(entry: HistoryEntry): string {
    const isActive = entry.id === this.currentDocumentIdValue
    const title = entry.title || '未命名文章'
    const themeName = entry.theme?.name || '未命名主题'
    const savedAt = new Date(entry.saved_at).toLocaleString('zh-CN', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    })
    
    return `
      <div class="history-entry group ${isActive ? 'bg-primary/10 border-primary' : 'bg-surface border-border hover:border-primary/50'} 
                  border rounded-lg p-4 transition-all cursor-pointer"
           data-action="click->history-panel#restore"
           data-document-id="${entry.id}">
        <div class="flex items-start justify-between mb-2">
          <h4 class="text-sm font-semibold text-foreground line-clamp-2 flex-1">
            ${this.escapeHtml(title)}
          </h4>
          <button type="button"
                  class="text-muted-foreground hover:text-destructive transition-colors opacity-0 group-hover:opacity-100"
                  data-action="click->history-panel#delete"
                  data-document-id="${entry.id}"
                  title="删除">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                    d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
          </button>
        </div>
        
        <div class="flex items-center justify-between text-xs text-muted-foreground">
          <span>${savedAt}</span>
          <span class="badge badge-sm badge-secondary">${this.escapeHtml(themeName)}</span>
        </div>
      </div>
    `
  }

  private applyDocument(document: HistoryEntry): void {
    // 触发自定义事件,由 wemd_editor_controller 监听并应用
    const event = new CustomEvent('history:restore', {
      detail: { document },
      bubbles: true
    })
    this.element.dispatchEvent(event)
  }

  private showLoading(): void {
    this.loadingStateTarget.classList.remove('hidden')
    this.listTarget.classList.add('hidden')
    this.emptyStateTarget.classList.add('hidden')
  }

  private showError(): void {
    this.loadingStateTarget.classList.add('hidden')
    this.emptyStateTarget.classList.remove('hidden')
    this.emptyStateTarget.innerHTML = '<p class="text-center text-muted-foreground">加载失败</p>'
  }

  private showToast(message: string, type: 'success' | 'error' = 'success'): void {
    if (typeof showToast === 'function') {
      showToast(message, type)
    } else {
      console.log(`[Toast] ${message}`)
    }
  }

  private getCsrfToken(): string {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? (meta as HTMLMetaElement).content : ''
  }

  private escapeHtml(text: string): string {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
