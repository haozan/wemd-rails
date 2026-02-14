// turbo-architecture-validation: disable
import { Controller } from "@hotwired/stimulus"
import { Application } from "@hotwired/stimulus"

// 声明全局 Turbo 类型
declare global {
  interface Window {
    Turbo: {
      renderStreamMessage(html: string): void
      visit(url: string): void
    }
    Stimulus: Application
  }
}

const Turbo = window.Turbo

export default class extends Controller<HTMLElement> {
  static targets = [
    "modal",
    "viewModal",
    "selectedDate",
    "viewDate",
    "searchInput",
    "documentCheckbox",
    "viewDocumentList"
  ]

  static values = {
    year: Number,
    month: Number
  }

  declare readonly modalTarget: HTMLElement
  declare readonly viewModalTarget: HTMLElement
  declare readonly selectedDateTarget: HTMLElement
  declare readonly viewDateTarget: HTMLElement
  declare readonly searchInputTarget: HTMLInputElement
  // stimulus-validator: disable-next-line
  declare readonly documentCheckboxTargets: HTMLInputElement[]
  declare readonly viewDocumentListTarget: HTMLElement
  declare readonly yearValue: number
  declare readonly monthValue: number

  private selectedDate: string = ""
  private searchTimeout: number | null = null

  connect(): void {
    console.log("Calendar controller connected")
  }

  disconnect(): void {
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }
  }

  // 选择日期，打开选择文章对话框
  selectDate(event: Event): void {
    const target = event.currentTarget as HTMLElement
    
    // 如果点击的是文章标签，不打开对话框
    if ((event.target as HTMLElement).tagName === 'A') {
      return
    }
    
    this.selectedDate = target.dataset.date || ""
    const dateObj = new Date(this.selectedDate)
    const formattedDate = `${dateObj.getFullYear()}年${dateObj.getMonth() + 1}月${dateObj.getDate()}日`
    
    this.selectedDateTarget.textContent = formattedDate
    this.showModal()
  }

  // 显示选择文章对话框
  showModal(): void {
    this.modalTarget.classList.remove("hidden")
    // 清空搜索框
    this.searchInputTarget.value = ""
    // 清空选中状态
    this.documentCheckboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
  }

  // 关闭选择文章对话框
  closeModal(): void {
    this.modalTarget.classList.add("hidden")
  }

  // 阻止事件冒泡
  stopPropagation(event: Event): void {
    event.stopPropagation()
  }

  // 搜索文章
  searchDocuments(): void {
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }

    this.searchTimeout = window.setTimeout(async () => {
      const query = this.searchInputTarget.value
      const url = `/calendars/search_documents?query=${encodeURIComponent(query)}`
      
      try {
        const response = await fetch(url, {
          headers: {
            'Accept': 'text/vnd.turbo-stream.html'
          }
        })
        
        if (response.ok) {
          const html = await response.text()
          // 让 Turbo 处理 stream 响应
          Turbo.renderStreamMessage(html)
        }
      } catch (error) {
        console.error('搜索文章失败:', error)
      }
    }, 300)
  }

  // 添加文章到日历
  async addDocuments(): Promise<void> {
    const selectedIds = this.documentCheckboxTargets
      .filter(checkbox => checkbox.checked)
      .map(checkbox => checkbox.value)
    
    if (selectedIds.length === 0) {
      showToast("请选择至少一篇文章", "error")
      return
    }

    const formData = new FormData()
    formData.append('date', this.selectedDate)
    selectedIds.forEach(id => formData.append('document_ids[]', id))

    try {
      const response = await fetch('/calendars/add_documents', {
        method: 'POST',
        headers: {
          'Accept': 'text/vnd.turbo-stream.html',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: formData
      })
      
      if (response.ok) {
        console.log('Add successful')
        
        // 关闭模态框
        this.closeModal()
        
        // 显示成功提示
        showToast('添加成功', 'success')
        
        // 等待一下让用户看到提示
        await new Promise(resolve => setTimeout(resolve, 300))
        
        // 使用 Turbo.visit 重新访问当前页面，确保 Stimulus 正确重新初始化
        if (typeof Turbo !== 'undefined' && Turbo.visit) {
          Turbo.visit(window.location.href, { action: 'replace' })
        } else {
          // fallback: 直接刷新页面
          window.location.reload()
        }
      } else {
        console.error('Response not ok:', response.status)
        showToast('添加文章失败，请重试', 'error')
      }
    } catch (error) {
      console.error('添加文章失败:', error)
      showToast('添加文章失败，请重试', 'error')
    }
  }

  // 查看或添加某天的文章（点击日期格子时）
  viewOrAddDocuments(event: Event): void {
    const target = event.currentTarget as HTMLElement
    const date = target.dataset.date || ""
    const documents = JSON.parse(target.dataset.documents || "[]")
    
    // 如果有文章，显示查看模态框
    if (documents.length > 0) {
      const dateObj = new Date(date)
      const formattedDate = `${dateObj.getFullYear()}年${dateObj.getMonth() + 1}月${dateObj.getDate()}日`
      
      this.viewDateTarget.textContent = formattedDate
      
      // 构建文章列表 HTML
      const documentsHTML = documents.map((doc: any) => `
        <div class="flex items-center justify-between p-3 rounded-lg bg-surface hover:bg-surface-hover transition-colors">
          <a href="/documents/${doc.id}/edit" class="flex-1 text-foreground hover:text-primary font-medium" data-turbo="false">
            ${doc.title}
          </a>
          <button type="button" 
                  class="btn-secondary btn-xs text-xs"
                  data-action="click->calendar#removeDocument"
                  data-document-id="${doc.id}"
                  data-date="${date}"
                  data-year="${dateObj.getFullYear()}"
                  data-month="${dateObj.getMonth() + 1}">
            移除
          </button>
        </div>
      `).join('')
      
      this.viewDocumentListTarget.innerHTML = documentsHTML
      this.showViewModal()
    } else {
      // 如果没有文章，打开添加文章模态框
      this.selectDate(event)
    }
  }

  // 查看某天的所有文章
  viewDocuments(event: Event): void {
    event.stopPropagation()
    const target = event.currentTarget as HTMLElement
    const date = target.dataset.date || ""
    const documents = JSON.parse(target.dataset.documents || "[]")
    
    const dateObj = new Date(date)
    const formattedDate = `${dateObj.getFullYear()}年${dateObj.getMonth() + 1}月${dateObj.getDate()}日`
    
    this.viewDateTarget.textContent = formattedDate
    
    // 构建文章列表 HTML
    const documentsHTML = documents.map((doc: any) => `
      <div class="flex items-center justify-between p-3 rounded-lg bg-surface hover:bg-surface-hover transition-colors">
        <a href="/documents/${doc.id}/edit" class="flex-1 text-foreground hover:text-primary font-medium" data-turbo="false">
          ${doc.title}
        </a>
        <button type="button" 
                class="btn-secondary btn-xs text-xs"
                data-action="click->calendar#removeDocument"
                data-document-id="${doc.id}"
                data-date="${date}"
                data-year="${dateObj.getFullYear()}"
                data-month="${dateObj.getMonth() + 1}">
          移除
        </button>
      </div>
    `).join('')
    
    this.viewDocumentListTarget.innerHTML = documentsHTML
    this.showViewModal()
  }

  // 显示查看文章对话框
  showViewModal(): void {
    this.viewModalTarget.classList.remove("hidden")
  }

  // 关闭查看文章对话框
  closeViewModal(): void {
    this.viewModalTarget.classList.add("hidden")
  }

  // 从查看模态框切换到添加模态框
  switchToAddModal(): void {
    // 从 viewDate 目标中提取日期信息
    const viewDateText = this.viewDateTarget.textContent || ""
    // 格式: "2025年2月14日"
    const match = viewDateText.match(/(\d{4})年(\d{1,2})月(\d{1,2})日/)
    
    if (match) {
      const year = match[1]
      const month = match[2].padStart(2, '0')
      const day = match[3].padStart(2, '0')
      this.selectedDate = `${year}-${month}-${day}`
      
      const formattedDate = `${year}年${month}月${day}日`
      this.selectedDateTarget.textContent = formattedDate
      
      // 关闭查看模态框，打开添加模态框
      this.closeViewModal()
      this.showModal()
    }
  }

  // 移除文章
  async removeDocument(event: Event): Promise<void> {
    const target = event.currentTarget as HTMLElement
    const documentId = target.dataset.documentId
    const date = target.dataset.date
    const year = target.dataset.year
    const month = target.dataset.month

    try {
      const response = await fetch(`/calendars/remove_document?document_id=${documentId}&date=${date}&year=${year}&month=${month}`, {
        method: 'DELETE',
        headers: {
          'Accept': 'text/vnd.turbo-stream.html',
          'X-CSRF-Token': this.getCSRFToken()
        }
      })
      
      if (response.ok) {
        console.log('Remove successful')
        
        // 关闭模态框
        this.closeViewModal()
        
        // 显示成功提示
        showToast('移除成功', 'success')
        
        // 等待一下让用户看到提示
        await new Promise(resolve => setTimeout(resolve, 300))
        
        // 使用 Turbo.visit 重新访问当前页面，确保 Stimulus 正确重新初始化
        if (typeof Turbo !== 'undefined' && Turbo.visit) {
          Turbo.visit(window.location.href, { action: 'replace' })
        } else {
          // fallback: 直接刷新页面
          window.location.reload()
        }
      } else {
        console.error('Remove response not ok:', response.status)
        showToast('移除文章失败，请重试', 'error')
      }
    } catch (error) {
      console.error('移除文章失败:', error)
      showToast('移除文章失败，请重试', 'error')
    }
  }

  // 处理保存目标表单提交成功
  handleGoalSaved(event: any): void {
    // 检查响应是否成功（HTTP 2xx）
    if (event.detail.success) {
      showToast('保存成功', 'success')
    }
  }

  // 重新连接 Stimulus 控制器（保留但不再使用）
  private reconnectStimulus(): void {
    // 这个方法不再需要，因为我们改用 outerHTML 替换
    // 保留代码以防以后需要
    console.log('reconnectStimulus called but not needed anymore')
  }

  // 获取 CSRF Token
  private getCSRFToken(): string {
    const meta = document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement
    return meta ? meta.content : ""
  }
}
