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
    "emptyState",
    "loadingState",
    "expandBtn"
  ]

  static values = {
    currentDocumentId: String
  }

  declare readonly sidebarTarget: HTMLElement
  declare readonly listTarget: HTMLElement
  declare readonly emptyStateTarget: HTMLElement
  declare readonly loadingStateTarget: HTMLElement
  declare readonly expandBtnTarget: HTMLElement
  declare readonly hasExpandBtnTarget: boolean
  declare readonly currentDocumentIdValue: string

  private history: HistoryEntry[] = []
  private filteredHistory: HistoryEntry[] = []
  private isCollapsed: boolean = false
  private readonly STORAGE_KEY = "wemd-sidebar-collapsed"

  connect(): void {
    // 恢复折叠状态
    try {
      this.isCollapsed = localStorage.getItem(this.STORAGE_KEY) === "1"
    } catch (_) {
      this.isCollapsed = false
    }
    this.applyCollapsedState()

    this.loadHistory()
    
    // 监听自动保存事件，刷新列表以更新主题标签
    window.addEventListener('document:autosaved', this.handleAutoSaved)
  }

  disconnect(): void {
    window.removeEventListener('document:autosaved', this.handleAutoSaved)
  }
  
  // 处理自动保存事件
  private handleAutoSaved = (): void => {
    // 重新加载历史列表，更新主题标签
    this.loadHistory()
  }

  // 切换侧边栏折叠/展开
  toggle(): void {
    this.isCollapsed = !this.isCollapsed
    try {
      localStorage.setItem(this.STORAGE_KEY, this.isCollapsed ? "1" : "0")
    } catch (_) {}
    this.applyCollapsedState()
  }

  // 关闭侧边栏（兼容旧 API：折叠）
  close(): void {
    if (!this.isCollapsed) {
      this.toggle()
    }
  }

  // 应用折叠状态到 DOM
  private applyCollapsedState(): void {
    const container = this.element.classList.contains("wemd-container")
      ? this.element
      : this.element.closest(".wemd-container") as HTMLElement | null

    if (this.isCollapsed) {
      this.sidebarTarget.classList.add("is-collapsed")
      container?.classList.add("sidebar-collapsed")
      if (this.hasExpandBtnTarget) {
        this.expandBtnTarget.classList.remove("hidden")
        this.expandBtnTarget.classList.add("flex")
      }
    } else {
      this.sidebarTarget.classList.remove("is-collapsed")
      container?.classList.remove("sidebar-collapsed")
      if (this.hasExpandBtnTarget) {
        this.expandBtnTarget.classList.add("hidden")
        this.expandBtnTarget.classList.remove("flex")
      }
    }
  }

  // 加载历史记录
  // turbo-architecture-validation: disable
  async loadHistory(): Promise<void> {
    try {
      this.showLoading()
      
      const response = await fetch('/documents.json')
      
      if (!response.ok) {
        throw new Error('Failed to load history')
      }
      
      const data = await response.json()
      
      this.history = data
      this.filteredHistory = this.history
      this.renderHistory()
    } catch (error) {
      console.error('[HistoryPanel] Load failed:', error)
      this.showError()
    }
  }

  // 搜索过滤（搜索框已移除，保留方法签名以防外部调用）
  search(): void {
    this.filteredHistory = this.history
    this.renderHistory()
  }

  // 恢复历史记录（切换到目标文档）
  // turbo-architecture-validation: disable
  async restore(event: Event): Promise<void> {
    event.preventDefault()
    const button = event.currentTarget as HTMLElement
    const documentId = button.dataset.documentId
    
    if (!documentId) return
    
    // 点击的是当前文档，无需跳转
    if (documentId === this.currentDocumentIdValue) return
    
    // 标记目标项为加载中（视觉反馈），不折叠侧栏避免快闪
    button.classList.add('is-loading')
    
    // 先保存当前编辑器内容
    await this.saveCurrentDocument()
    
    // 走 Turbo Drive 局部导航，避免整页刷新（白屏 + 重新下载所有 JS/CSS）
    window.Turbo.visit(`/documents/${documentId}/edit`)
  }
  
  /**
   * 保存当前编辑器中的文档（切换前）
   */
  private async saveCurrentDocument(): Promise<void> {
    // 查找页面上的 wemd-editor controller 实例
    const editorElement = document.querySelector('[data-controller~="wemd-editor"]')
    if (!editorElement) {
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
    
    // 添加删除确认
    const confirmed = window.confirm('确定要删除这篇文档吗？此操作无法撤销。')
    if (!confirmed) return
    
    try {
      const response = await fetch(`/documents/${documentId}.json`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': this.getCsrfToken(),
          'Content-Type': 'application/json'
        }
      })
      
      if (!response.ok) {
        // 如果是 404 错误，说明文档已经不存在，直接刷新列表
        if (response.status === 404) {
          await this.loadHistory()
          this.showToast('文档不存在，已刷新列表', 'error')
          return
        }
        
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
      // 发生任何错误时都刷新列表，确保显示的是最新状态
      await this.loadHistory()
      this.showToast(errorMessage, 'error')
    }
  }

  // 清空所有历史
  // turbo-architecture-validation: disable
  async clearAll(): Promise<void> {
    // 添加清空历史确认
    const confirmed = window.confirm('确定要清空所有历史记录吗？此操作无法撤销。')
    if (!confirmed) return
    
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
    // 走 Turbo Drive 局部导航，避免整页刷新
    window.Turbo.visit('/documents/new')
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
      
      // 按时间分组
      const groups = this.groupByTime(this.filteredHistory)
      const html = groups.map(g => {
        const items = g.entries.map(e => this.renderEntry(e)).join('')
        return `<div class="history-group-label">${g.label}</div>${items}`
      }).join('')
      this.listTarget.innerHTML = html
    }
  }

  private groupByTime(entries: HistoryEntry[]): { label: string; entries: HistoryEntry[] }[] {
    const now = new Date()
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
    const startOfYesterday = startOfToday - 86400000
    const startOfWeek = startOfToday - 6 * 86400000
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1).getTime()

    const buckets: Record<string, HistoryEntry[]> = {
      '今天': [],
      '昨天': [],
      '本周': [],
      '本月': [],
      '更早': []
    }

    for (const entry of entries) {
      const t = new Date(entry.saved_at).getTime()
      if (t >= startOfToday) buckets['今天'].push(entry)
      else if (t >= startOfYesterday) buckets['昨天'].push(entry)
      else if (t >= startOfWeek) buckets['本周'].push(entry)
      else if (t >= startOfMonth) buckets['本月'].push(entry)
      else buckets['更早'].push(entry)
    }

    return Object.entries(buckets)
      .filter(([_, list]) => list.length > 0)
      .map(([label, list]) => ({ label, entries: list }))
  }

  private formatRelativeTime(dateStr: string): string {
    const t = new Date(dateStr).getTime()
    const diff = Date.now() - t
    const min = Math.floor(diff / 60000)
    if (min < 1) return '刚刚'
    if (min < 60) return `${min} 分钟前`
    const hr = Math.floor(min / 60)
    if (hr < 24) return `${hr} 小时前`
    const day = Math.floor(hr / 24)
    if (day < 7) return `${day} 天前`
    const d = new Date(dateStr)
    const now = new Date()
    if (d.getFullYear() === now.getFullYear()) {
      return `${d.getMonth() + 1}/${d.getDate()}`
    }
    return `${d.getFullYear()}/${d.getMonth() + 1}/${d.getDate()}`
  }

  private renderEntry(entry: HistoryEntry): string {
    const isActive = entry.id === this.currentDocumentIdValue
    const title = entry.title || '未命名文章'
    const themeName = entry.theme?.name || ''
    const savedAt = this.formatRelativeTime(entry.saved_at)
    
    return `
      <div class="history-entry group ${isActive ? 'is-active' : ''}"
           data-action="click->history-panel#restore"
           data-document-id="${entry.id}">
        <div class="flex items-center gap-2">
          <h4 class="text-foreground truncate flex-1 min-w-0">
            ${this.escapeHtml(title)}
          </h4>
          <div class="entry-actions flex items-center gap-0.5 flex-shrink-0">
            <button type="button"
                    class="text-muted-foreground hover:text-primary transition-colors rounded hover:bg-surface"
                    data-action="click->history-panel#rename"
                    data-document-id="${entry.id}"
                    title="重命名">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                      d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
              </svg>
            </button>
            <button type="button"
                    class="text-muted-foreground hover:text-primary transition-colors rounded hover:bg-surface"
                    data-action="click->history-panel#duplicate"
                    data-document-id="${entry.id}"
                    title="复制">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                      d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
              </svg>
            </button>
            <button type="button"
                    class="text-muted-foreground hover:text-destructive transition-colors rounded hover:bg-surface"
                    data-action="click->history-panel#delete"
                    data-document-id="${entry.id}"
                    title="删除">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                      d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
            </button>
          </div>
        </div>

        <div class="entry-meta flex items-center gap-1.5">
          <span class="flex-shrink-0">${savedAt}</span>
          ${themeName ? `<span class="truncate">· ${this.escapeHtml(themeName)}</span>` : ''}
        </div>
      </div>
    `
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
