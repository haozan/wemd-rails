import { Controller } from "@hotwired/stimulus"
import { parseMarkdown, applyTheme } from "../lib/markdown_parser"
import juice from 'juice'

export default class extends Controller<HTMLElement> {
  static targets = [
    "form",
    "titleInput",
    "editor",
    "preview",
    "themeSelect",
    "copyButton",
    "saveStatus"
  ]

  static values = {
    themes: Array
  }

  // Declare target types
  declare readonly formTarget: HTMLFormElement
  declare readonly titleInputTarget: HTMLInputElement
  declare readonly editorTarget: HTMLTextAreaElement
  declare readonly previewTarget: HTMLElement
  declare readonly themeSelectTarget: HTMLSelectElement
  declare readonly copyButtonTarget: HTMLButtonElement
  declare readonly saveStatusTarget: HTMLElement
  declare readonly hasCopyButtonTarget: boolean
  declare readonly hasSaveStatusTarget: boolean
  
  // Declare value types
  declare themesValue: Array<{ id: number; name: string; css: string }>

  private debounceTimer: number | null = null
  private autoSaveTimer: number | null = null
  private showHeadingMenu: boolean = false
  private showListMenu: boolean = false
  private showChartMenu: boolean = false
  private headingMenuRef: HTMLElement | null = null
  private listMenuRef: HTMLElement | null = null
  private chartMenuRef: HTMLElement | null = null

  connect(): void {
    console.log("WeMD Editor connected")
    console.log('[WeMD Debug] Checking saveStatus target...', {
      hasSaveStatusTarget: this.hasSaveStatusTarget,
      saveStatusElement: this.hasSaveStatusTarget ? this.saveStatusTarget : null
    })
    
    this.updatePreview()
    this.setupAutoSave()
    
    // 初始化状态显示为"已保存"
    if (this.hasSaveStatusTarget) {
      console.log('[WeMD Debug] Initializing save status to "saved"')
      this.updateSaveStatus('saved')
    } else {
      console.warn('[WeMD Debug] saveStatus target not found!')
    }
    
    this.setupOutsideClickHandler()
  }

  disconnect(): void {
    // 在页面卸载前立即保存（如果有未保存的更改）
    if (this.autoSaveTimer) {
      clearTimeout(this.autoSaveTimer)
      console.log('[WeMD AutoSave] disconnect - performing immediate save before unmount')
      this.performAutoSaveSync()
    }
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
    document.removeEventListener('mousedown', this.handleOutsideClick)
  }

  /**
   * 简化 KaTeX 公式以提高微信兼容性
   * 策略：提取 annotation 中的原始 LaTeX 代码，用简单样式包裹
   */
  private simplifyKatexForWechat(html: string): string {
    const tempDiv = document.createElement('div')
    tempDiv.innerHTML = html
    
    const katexElements = tempDiv.querySelectorAll('.katex')
    
    katexElements.forEach(katex => {
      const annotation = katex.querySelector('annotation[encoding="application/x-tex"]')
      if (annotation) {
        const latex = annotation.textContent || ''
        const isDisplay = katex.classList.contains('katex-display')
        
        if (isDisplay) {
          // 块级公式：使用带边框的容器
          const container = document.createElement('div')
          container.style.cssText = `
            background: #f5f5f5;
            border-left: 3px solid #42b983;
            padding: 12px 16px;
            margin: 16px 0;
            font-family: 'Courier New', monospace;
            font-size: 14px;
            overflow-x: auto;
            color: #2c3e50;
          `
          container.textContent = latex
          katex.replaceWith(container)
        } else {
          // 行内公式：使用简单的 code 标签
          const code = document.createElement('code')
          code.style.cssText = `
            background: #f0f0f0;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
            color: #e83e8c;
          `
          code.textContent = latex
          katex.replaceWith(code)
        }
      }
    })
    
    return tempDiv.innerHTML
  }

  /**
   * 更新预览（防抖处理）
   */
  updatePreview(): void {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    this.debounceTimer = window.setTimeout(() => {
      this.renderPreview()
    }, 300)
  }

  /**
   * 渲染 Markdown 预览
   */
  private renderPreview(): void {
    const markdown = this.editorTarget.value
    const html = parseMarkdown(markdown)
    
    // 获取选中的主题 CSS
    const themeId = this.themeSelectTarget.value
    if (themeId) {
      // 从 themesValue 中获取主题 CSS
      const themeData = this.getThemeData(themeId)
      const themeStyles = themeData?.css || ''
      
      // 更新页面上的 style 标签（先清空再设置，避免样式堆积）
      const styleElement = document.getElementById('theme-styles')
      if (styleElement) {
        styleElement.textContent = themeStyles
      }
      
      // 应用主题包裹到预览区域
      this.previewTarget.innerHTML = applyTheme(html)
    } else {
      // 没有选择主题时，清空样式
      const styleElement = document.getElementById('theme-styles')
      if (styleElement) {
        styleElement.textContent = ''
      }
      this.previewTarget.innerHTML = applyTheme(html)
    }

    // 触发代码高亮和其他渲染后处理
    this.postRenderHooks()
  }

  /**
   * 从 themesValue 获取主题数据
   */
  private getThemeData(themeId: string): { id: number; name: string; css: string } | undefined {
    if (!this.themesValue || this.themesValue.length === 0) return undefined
    return this.themesValue.find((theme: any) => String(theme.id) === String(themeId))
  }

  /**
   * 渲染后处理（Mermaid 图表等）
   */
  private postRenderHooks(): void {
    // 如果有 Mermaid 图表，初始化它们
    // stimulus-validator: disable-next-line
    const mermaidBlocks = this.previewTarget.querySelectorAll('.mermaid')
    if (mermaidBlocks.length > 0 && window.mermaid) {
      window.mermaid.init(undefined, mermaidBlocks as NodeListOf<HTMLElement>)
    }
  }

  /**
   * 工具栏操作：插入加粗
   */
  insertBold(): void {
    this.wrapSelection('**', '**', '加粗文本')
  }

  /**
   * 工具栏操作：插入斜体
   */
  insertItalic(): void {
    this.wrapSelection('*', '*', '斜体文本')
  }

  /**
   * 工具栏操作：切换标题菜单
   */
  toggleHeadingMenu(event: Event): void {
    event.stopPropagation()
    this.showHeadingMenu = !this.showHeadingMenu
    this.showListMenu = false
    this.showChartMenu = false
    this.updateDropdownMenus()
  }

  /**
   * 插入指定级别的标题
   */
  insertHeadingLevel(event: Event): void {
    const button = event.currentTarget as HTMLElement
    const prefix = button.dataset.prefix || '## '
    const placeholder = button.dataset.placeholder || '标题'
    this.insertAtCursor(prefix, placeholder)
    this.showHeadingMenu = false
    this.updateDropdownMenus()
  }

  /**
   * 工具栏操作：插入链接
   */
  insertLink(): void {
    this.wrapSelection('[', '](https://example.com)', '链接文本')
  }

  /**
   * 工具栏操作：插入图片（触发上传）
   */
  insertImage(): void {
    // 触发图片上传对话框
    const uploadEvent = new CustomEvent('trigger-image-upload', { bubbles: true })
    this.element.dispatchEvent(uploadEvent)
  }

  /**
   * 处理图片上传成功事件
   */
  handleImageUploaded(event: CustomEvent): void {
    const { url, filename } = event.detail
    const altText = filename.replace(/\.[^/.]+$/, '') // Remove extension
    this.insertAtCursor(`![${altText}](${url})`, '')
  }

  /**
   * 工具栏操作：插入代码块
   */
  insertCode(): void {
    this.insertAtCursor('\n```javascript\n', 'console.log("Hello World")\n```\n')
  }

  /**
   * 工具栏操作：插入数学公式块
   */
  insertMath(): void {
    this.insertAtCursor('$$\n', 'f(x) = \\int_{-\\infty}^{\\infty} \\hat{f}(\\xi) e^{2\\pi i \\xi x} d\\xi\n$$\n')
  }

  /**
   * 工具栏操作：插入行内数学公式
   */
  insertInlineMath(): void {
    this.wrapSelection('$', '$', 'E=mc^2')
  }

  /**
   * 工具栏操作：切换图表菜单
   */
  toggleChartMenu(event: Event): void {
    event.stopPropagation()
    this.showChartMenu = !this.showChartMenu
    this.showHeadingMenu = false
    this.showListMenu = false
    this.updateDropdownMenus()
  }

  /**
   * 插入指定的 Mermaid 图表模板
   */
  insertChartTemplate(event: Event): void {
    const button = event.currentTarget as HTMLElement
    const template = button.dataset.template || ''
    if (template) {
      this.insertAtCursor('```mermaid\n', `${template}\n\`\`\`\n`)
      this.showChartMenu = false
      this.updateDropdownMenus()
    }
  }

  /**
   * 工具栏操作：切换列表菜单
   */
  toggleListMenu(event: Event): void {
    event.stopPropagation()
    this.showListMenu = !this.showListMenu
    this.showHeadingMenu = false
    this.showChartMenu = false
    this.updateDropdownMenus()
  }

  /**
   * 插入指定类型的列表
   */
  insertListType(event: Event): void {
    const button = event.currentTarget as HTMLElement
    const prefix = button.dataset.prefix || '- '
    const placeholder = button.dataset.placeholder || '列表项'
    this.insertAtCursor(prefix, placeholder)
    this.showListMenu = false
    this.updateDropdownMenus()
  }

  /**
   * 工具栏操作：插入引用
   */
  insertQuote(): void {
    this.insertAtCursor('> ', '引用内容')
  }

  /**
   * 复制到微信公众号（应用深色模式算法 + 内联样式）
   */
  async copyToWechat(): Promise<void> {
    try {
      const markdown = this.editorTarget.value
      const html = parseMarkdown(markdown)
      
      // 获取主题 CSS（从更新后的 style 标签）
      const themeStyles = document.getElementById('theme-styles')?.textContent || ''
      
      // 为 juice构造包含<style>标签的HTML（juice需要这个来转换为内联样式）
      const styledHtml = `
        <style>${themeStyles}</style>
        ${applyTheme(html)}
      `
      
      // 使用 juice 库将 CSS 转为内联样式
      let finalHtml = juice(styledHtml)
      
      // 处理 KaTeX 公式：将复杂的 KaTeX HTML 转为 LaTeX 源代码
      if (finalHtml.includes('class="katex"')) {
        finalHtml = this.simplifyKatexForWechat(finalHtml)
      }
      
      // 清理 HTML（移除<style>标签，因为已经转换为内联样式）
      finalHtml = finalHtml.trim().replace(/<style[^>]*>\s*<\/style>/gi, '')
      
      // 复制到剪贴板
      await this.copyHtmlToClipboard(finalHtml)
      
      if (typeof showToast === 'function') {
        showToast('✅ 已复制到剪贴板！可直接粘贴到微信公众号编辑器', 'success')
      }
    } catch (error) {
      console.error('复制失败:', error)
      if (typeof showToast === 'function') {
        showToast('❌ 复制失败，请重试', 'error')
      }
    }
  }

  /**
   * 设置点击外部关闭下拉菜单的处理器
   */
  private setupOutsideClickHandler(): void {
    this.handleOutsideClick = this.handleOutsideClick.bind(this)
    document.addEventListener('mousedown', this.handleOutsideClick)
  }

  /**
   * 处理点击外部关闭菜单
   */
  private handleOutsideClick = (event: MouseEvent): void => {
    const target = event.target as Node
    
    // 检查是否点击在下拉菜单或按钮内部
    const clickedInsideHeading = this.headingMenuRef?.contains(target)
    const clickedInsideList = this.listMenuRef?.contains(target)
    const clickedInsideChart = this.chartMenuRef?.contains(target)
    
    if (!clickedInsideHeading && !clickedInsideList && !clickedInsideChart) {
      this.showHeadingMenu = false
      this.showListMenu = false
      this.showChartMenu = false
      this.updateDropdownMenus()
    }
  }

  /**
   * 更新下拉菜单的显示状态
   */
  private updateDropdownMenus(): void {
    // 更新标题菜单
    this.headingMenuRef = this.element.querySelector('.wemd-heading-dropdown')
    const headingButton = this.element.querySelector('[data-action*="toggleHeadingMenu"]')
    const headingMenu = this.element.querySelector('.wemd-heading-menu')
    
    if (headingButton) {
      headingButton.classList.toggle('active', this.showHeadingMenu)
    }
    if (headingMenu) {
      headingMenu.classList.toggle('hidden', !this.showHeadingMenu)
    }

    // 更新列表菜单
    this.listMenuRef = this.element.querySelector('.wemd-list-dropdown')
    const listButton = this.element.querySelector('[data-action*="toggleListMenu"]')
    const listMenu = this.element.querySelector('.wemd-list-menu')
    
    if (listButton) {
      listButton.classList.toggle('active', this.showListMenu)
    }
    if (listMenu) {
      listMenu.classList.toggle('hidden', !this.showListMenu)
    }

    // 更新图表菜单
    this.chartMenuRef = this.element.querySelector('.wemd-chart-dropdown')
    const chartButton = this.element.querySelector('[data-action*="toggleChartMenu"]')
    const chartMenu = this.element.querySelector('.wemd-chart-menu')
    
    if (chartButton) {
      chartButton.classList.toggle('active', this.showChartMenu)
    }
    if (chartMenu) {
      chartMenu.classList.toggle('hidden', !this.showChartMenu)
    }
  }

  /**
   * 工具方法：在光标位置插入文本
   */
  private insertAtCursor(before: string, placeholder: string): void {
    const editor = this.editorTarget
    const start = editor.selectionStart
    const end = editor.selectionEnd
    const text = editor.value

    const newText = text.substring(0, start) + before + placeholder + text.substring(end)
    editor.value = newText
    
    // 设置新的光标位置
    const newCursorPos = start + before.length + placeholder.length
    editor.setSelectionRange(newCursorPos, newCursorPos)
    editor.focus()

    // 触发预览更新
    this.updatePreview()
  }

  /**
   * 工具方法：包裹选中文本
   */
  private wrapSelection(before: string, after: string, placeholder: string): void {
    const editor = this.editorTarget
    const start = editor.selectionStart
    const end = editor.selectionEnd
    const text = editor.value
    const selectedText = text.substring(start, end)

    const replacement = before + (selectedText || placeholder) + after
    const newText = text.substring(0, start) + replacement + text.substring(end)
    editor.value = newText
    
    // 选中新插入的内容
    if (selectedText) {
      editor.setSelectionRange(start, start + replacement.length)
    } else {
      editor.setSelectionRange(start + before.length, start + before.length + placeholder.length)
    }
    editor.focus()

    // 触发预览更新
    this.updatePreview()
  }

  /**
   * 复制 HTML 到剪贴板（保留样式）
   * 使用多种方法以提高浏览器兼容性
   */
  private async copyHtmlToClipboard(html: string): Promise<void> {
    // 方法 1: 使用 DOM 选择方法（最佳兼容性，保留格式）
    const tempDiv = document.createElement('div')
    tempDiv.innerHTML = html
    tempDiv.style.position = 'fixed'
    tempDiv.style.left = '-9999px'
    tempDiv.style.top = '0'
    tempDiv.style.opacity = '0'
    tempDiv.style.pointerEvents = 'none'
    document.body.appendChild(tempDiv)
    
    const selection = window.getSelection()
    const range = document.createRange()
    
    try {
      range.selectNodeContents(tempDiv)
      selection?.removeAllRanges()
      selection?.addRange(range)
      
      const successful = document.execCommand('copy')
      
      if (successful) {
        selection?.removeAllRanges()
        document.body.removeChild(tempDiv)
        return
      }
    } catch (error) {
      console.warn('DOM selection method failed:', error)
    }
    
    // 清理第一次尝试的元素
    selection?.removeAllRanges()
    if (document.body.contains(tempDiv)) {
      document.body.removeChild(tempDiv)
    }
    
    // 方法 2: 使用 Clipboard API 作为备选
    const plainText = tempDiv.innerText || tempDiv.textContent || ''
    
    try {
      if (navigator.clipboard && window.ClipboardItem) {
        const clipboardItem = new ClipboardItem({
          'text/html': new Blob([html], { type: 'text/html' }),
          'text/plain': new Blob([plainText], { type: 'text/plain' })
        })
        await navigator.clipboard.write([clipboardItem])
        return
      }
    } catch (error) {
      console.warn('Clipboard API also failed:', error)
      throw new Error('所有复制方法都失败了')
    }
  }

  /**
   * 设置自动保存（检测未保存更改）
   */
  private setupAutoSave(): void {
    // 监听编辑器内容变化和主题选择变化
    const triggerAutoSave = () => {
      console.log('[WeMD AutoSave] triggerAutoSave called - starting 2s debounce timer')
      
      // 显示"编辑中"状态
      this.updateSaveStatus('editing')
      
      if (this.autoSaveTimer) {
        console.log('[WeMD AutoSave] Clearing existing timer')
        clearTimeout(this.autoSaveTimer)
      }

      // 使用 2 秒防抖
      this.autoSaveTimer = window.setTimeout(() => {
        console.log('[WeMD AutoSave] Debounce timer expired, calling performAutoSave')
        this.performAutoSave()
      }, 2000)
    }

    this.editorTarget.addEventListener('input', triggerAutoSave)
    this.titleInputTarget.addEventListener('input', triggerAutoSave)
    this.themeSelectTarget.addEventListener('change', triggerAutoSave)
    console.log('[WeMD AutoSave] Auto-save listeners registered on editor, title, and theme select')
  }

  /**
   * 同步执行自动保存（不使用 async，用于 disconnect 等需要立即保存的场景）
   */
  private performAutoSaveSync(): void {
    console.log('[WeMD AutoSave] performAutoSaveSync called (synchronous save)')
    
    // 使用 sendBeacon 或同步 XMLHttpRequest 确保在页面卸载前完成保存
    const formData = new FormData(this.formTarget)
    
    console.log('[WeMD AutoSave] Sending synchronous save to', this.formTarget.action)
    
    // 优先使用 sendBeacon（更可靠）
    if (navigator.sendBeacon) {
      try {
        const sent = navigator.sendBeacon(this.formTarget.action, formData)
        if (sent) {
          console.log('[WeMD AutoSave] Sync save sent via sendBeacon')
        } else {
          console.warn('[WeMD AutoSave] sendBeacon failed, trying XMLHttpRequest')
          this.performSyncXHR(formData)
        }
      } catch (error) {
        console.error('[WeMD AutoSave] sendBeacon error:', error)
        this.performSyncXHR(formData)
      }
    } else {
      this.performSyncXHR(formData)
    }
  }
  
  /**
   * 使用同步 XMLHttpRequest 作为 sendBeacon 的后备方案
   */
  private performSyncXHR(formData: FormData): void {
    const xhr = new XMLHttpRequest()
    xhr.open('PATCH', this.formTarget.action, false) // false = 同步请求
    xhr.setRequestHeader('X-CSRF-Token', this.getCSRFToken())
    try {
      xhr.send(formData)
      console.log('[WeMD AutoSave] Sync save completed via XHR, status:', xhr.status)
    } catch (error) {
      console.error('[WeMD AutoSave] Sync XHR failed:', error)
    }
  }

  /**
   * 执行自动保存
   */
  private async performAutoSave(): Promise<void> {
    console.log('[WeMD AutoSave] performAutoSave called', {
      formAction: this.formTarget.action
    })
    
    // 使用 fetch 发送静默更新
    const formData = new FormData(this.formTarget)
    
    console.log('[WeMD AutoSave] Sending PATCH request to', this.formTarget.action)
    
    try {
      const response = await fetch(this.formTarget.action, {
        method: 'PATCH',
        body: formData,
        headers: {
          'X-CSRF-Token': this.getCSRFToken(),
          'Accept': 'text/html'
        }
      })
      
      if (!response.ok) {
        const errorText = await response.text()
        console.error('[WeMD AutoSave] 自动保存失败:', `Status ${response.status} - ${response.statusText}`, errorText)
        this.updateSaveStatus('error')
      } else {
        console.log('[WeMD AutoSave] Auto-save successful, dispatching event')
        // 显示"已保存"状态
        this.updateSaveStatus('saved')
        // 自动保存成功后，派发事件通知历史面板刷新
        // 这样主题切换后能立即在文章目录中看到更新的主题标签
        window.dispatchEvent(new CustomEvent('document:autosaved'))
      }
    } catch (error) {
      // 只在非网络错误时记录（网络离线等情况不应显示错误）
      if (error instanceof Error && error.message !== 'Failed to fetch') {
        console.error('[WeMD AutoSave] 自动保存错误:', error.message, error)
      }
    }
  }

  /**
   * 获取 CSRF Token
   */
  private getCSRFToken(): string {
    const meta = document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement
    return meta ? meta.content : ''
  }

  /**
   * 更新保存状态显示
   */
  private updateSaveStatus(status: 'editing' | 'saved' | 'error'): void {
    if (!this.hasSaveStatusTarget) return
    
    const statusConfig = {
      editing: { text: '编辑中...', class: 'text-yellow-600' },
      saved: { text: '已保存', class: 'text-green-600' },
      error: { text: '保存失败', class: 'text-red-600' }
    }
    
    const config = statusConfig[status]
    this.saveStatusTarget.textContent = config.text
    this.saveStatusTarget.className = `text-sm ${config.class}`
    
    console.log('[WeMD AutoSave] Status updated to:', status)
  }

  /**
   * 立即保存当前文档（供外部调用，如切换前保存）
   */
  saveBeforeSwitch(): Promise<void> {
    console.log('[WeMD AutoSave] saveBeforeSwitch called - performing immediate save')
    
    // 清除防抖定时器
    if (this.autoSaveTimer) {
      clearTimeout(this.autoSaveTimer)
      this.autoSaveTimer = null
    }
    
    // 立即执行保存
    return this.performAutoSave()
  }

  /**
   * 从历史记录恢复文档
   */
  restoreFromHistory(event: CustomEvent): void {
    const { document } = event.detail
    if (!document) return

    // 直接恢复文档（自动保存会在用户编辑时保存内容，无需阻止切换）
    // 恢复标题
    if (this.titleInputTarget) {
      this.titleInputTarget.value = document.title || '未命名文章'
    }

    // 恢复内容
    this.editorTarget.value = document.content || ''

    // 恢复主题
    if (this.themeSelectTarget && document.theme_id) {
      this.themeSelectTarget.value = document.theme_id.toString()
    }

    // 更新预览
    this.renderPreview()

    // 显示提示
    if (typeof showToast === 'function') {
      showToast('已恢复历史记录', 'success')
    }
  }
}

// 扩展 Window 类型以支持 mermaid
declare global {
  interface Window {
    mermaid?: {
      init: (config?: any, nodes?: string | HTMLElement | NodeListOf<HTMLElement>) => Promise<void>
      initialize: (config: any) => void
      run?: (config?: any) => Promise<void>
    }
  }
}
