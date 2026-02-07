import { Controller } from "@hotwired/stimulus"

interface HistoryEntry {
  id: string  // friendly_id (slug)
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
    
    // 监听自动保存事件，刷新列表以更新主题标签
    window.addEventListener('document:autosaved', this.handleAutoSaved)
  }

  disconnect(): void {
    console.log("[HistoryPanel] disconnected")
    window.removeEventListener('document:autosaved', this.handleAutoSaved)
  }
  
  // 处理自动保存事件
  private handleAutoSaved = (): void => {
    // 重新加载历史列表，更新主题标签
    this.loadHistory()
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

  // 恢复历史记录（切换到目标文档）
  // turbo-architecture-validation: disable
  async restore(event: Event): Promise<void> {
    event.preventDefault()
    const button = event.currentTarget as HTMLElement
    const documentId = button.dataset.documentId
    
    if (!documentId) return
    
    // 立即关闭侧边栏，避免跳转前闪烁
    this.close()
    
    // 先保存当前编辑器内容
    console.log('[HistoryPanel] Saving current document before switching')
    await this.saveCurrentDocument()
    
    // 直接跳转到目标文档的编辑页面
    console.log('[HistoryPanel] Navigating to document:', documentId)
    window.location.href = `/documents/${documentId}/edit`
  }
  
  /**
   * 保存当前编辑器中的文档（切换前）
   */
  private async saveCurrentDocument(): Promise<void> {
    // 查找页面上的 wemd-editor controller 实例
    const editorElement = document.querySelector('[data-controller~="wemd-editor"]')
    if (!editorElement) {
      console.log('[HistoryPanel] No editor found, skip save')
      return
    }
    
    // 获取 Stimulus controller 实例
    const editorController = this.application.getControllerForElementAndIdentifier(
      editorElement as HTMLElement,
      'wemd-editor'
    )
    
    if (editorController && typeof (editorController as any).saveBeforeSwitch === 'function') {
      try {
        await (editorController as any).saveBeforeSwitch()
        console.log('[HistoryPanel] Current document saved before restore')
      } catch (error) {
        console.error('[HistoryPanel] Save before restore failed:', error)
      }
    }
  }

  // 重命名文章
  // turbo-architecture-validation: disable
  async rename(event: Event): Promise<void> {
    event.preventDefault()
    event.stopPropagation()
    
    const button = event.currentTarget as HTMLElement
    const documentId = button.dataset.documentId
    
    if (!documentId) return
    
    // 获取当前文章信息
    const entry = this.history.find(e => e.id === documentId)
    if (!entry) return
    
    // 获取对应的标题元素
    const historyEntry = button.closest('.history-entry')
    if (!historyEntry) return
    
    const titleElement = historyEntry.querySelector('h4')
    if (!titleElement) return
    
    const currentTitle = entry.title || '未命名文章'
    
    // 创建输入框替换标题
    const input = document.createElement('input')
    input.type = 'text'
    input.value = currentTitle
    input.className = 'w-full px-2 py-1 text-sm border border-primary rounded focus:outline-none focus:ring-2 focus:ring-primary'
    
    // 保存原始内容
    const originalContent = titleElement.innerHTML
    
    // 替换为输入框
    titleElement.innerHTML = ''
    titleElement.appendChild(input)
    input.focus()
    input.select()
    
    // 保存函数
    const save = async () => {
      const newTitle = input.value.trim()
      
      if (!newTitle || newTitle === currentTitle) {
        titleElement.innerHTML = originalContent
        return
      }
      
      try {
        const response = await fetch(`/documents/${documentId}.json`, {
          method: 'PATCH',
          headers: {
            'X-CSRF-Token': this.getCsrfToken(),
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({ document: { title: newTitle } })
        })
        
        if (!response.ok) throw new Error('Failed to rename')
        
        // 更新本地数据
        entry.title = newTitle
        const filteredEntry = this.filteredHistory.find(e => e.id === documentId)
        if (filteredEntry) {
          filteredEntry.title = newTitle
        }
        
        this.renderHistory()
        this.showToast('重命名成功')
      } catch (error) {
        console.error('[HistoryPanel] Rename failed:', error)
        titleElement.innerHTML = originalContent
        this.showToast('重命名失败,请重试', 'error')
      }
    }
    
    // 取消函数
    const cancel = () => {
      titleElement.innerHTML = originalContent
    }
    
    // 监听回车键保存
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        e.preventDefault()
        save()
      } else if (e.key === 'Escape') {
        e.preventDefault()
        cancel()
      }
    })
    
    // 监听失去焦点时保存
    input.addEventListener('blur', () => {
      setTimeout(() => save(), 100)
    })
  }

  // 复制文章
  // turbo-architecture-validation: disable
  async duplicate(event: Event): Promise<void> {
    event.preventDefault()
    event.stopPropagation()
    
    const button = event.currentTarget as HTMLElement
    const documentId = button.dataset.documentId
    
    if (!documentId) return
    
    try {
      const response = await fetch(`/documents/${documentId}/duplicate.json`, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': this.getCsrfToken(),
          'Content-Type': 'application/json'
        }
      })
      
      if (!response.ok) throw new Error('Failed to duplicate')
      
      const data = await response.json()
      
      if (data.success) {
        // 重新加载整个历史列表，避免重复添加
        await this.loadHistory()
        this.showToast('复制成功')
      }
    } catch (error) {
      console.error('[HistoryPanel] Duplicate failed:', error)
      this.showToast('复制失败,请重试', 'error')
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
      
      // 重新加载整个历史列表，确保删除生效
      await this.loadHistory()
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
  createNew(): void {
    // 直接跳转到 /documents/new，后端会创建文档并重定向到编辑页
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
          <div class="flex items-center gap-1 opacity-0 group-hover:opacity-100">
            <button type="button"
                    class="text-muted-foreground hover:text-primary transition-colors"
                    data-action="click->history-panel#rename"
                    data-document-id="${entry.id}"
                    title="重命名">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                      d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
              </svg>
            </button>
            <button type="button"
                    class="text-muted-foreground hover:text-primary transition-colors"
                    data-action="click->history-panel#duplicate"
                    data-document-id="${entry.id}"
                    title="复制">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                      d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
              </svg>
            </button>
            <button type="button"
                    class="text-muted-foreground hover:text-destructive transition-colors"
                    data-action="click->history-panel#delete"
                    data-document-id="${entry.id}"
                    title="删除">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                      d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
            </button>
          </div>
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
