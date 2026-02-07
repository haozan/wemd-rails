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
    "copyButton"
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
  declare readonly hasCopyButtonTarget: boolean
  
  // Declare value types
  declare themesValue: Array<{ id: number; name: string; css: string }>

  private debounceTimer: number | null = null
  private autoSaveTimer: number | null = null
  private isNewDocument: boolean = false
  private documentCreated: boolean = false
  private showHeadingMenu: boolean = false
  private showListMenu: boolean = false
  private showChartMenu: boolean = false
  private headingMenuRef: HTMLElement | null = null
  private listMenuRef: HTMLElement | null = null
  private chartMenuRef: HTMLElement | null = null

  connect(): void {
    console.log("WeMD Editor connected")
    // 检测是否为新建文档页面（通过 URL 判断）
    this.isNewDocument = window.location.pathname.includes('/documents/new')
    
    // 初始化时渲染一次预览
    this.updatePreview()
    
    // 添加自动保存提示
    this.setupAutoSave()
    
    // 设置点击外部关闭菜单
    this.setupOutsideClickHandler()
    
    // 监听表单提交结果
    this.formTarget.addEventListener('turbo:submit-end', (event: any) => {
      if (this.isNewDocument && event.detail.success) {
        // 新建文档成功后，标记为已创建，不再是新建页面
        // Turbo 会自动跳转到 edit 页面
        this.documentCreated = true
        
        // 显示复制到微信按钮
        if (this.hasCopyButtonTarget) {
          this.copyButtonTarget.classList.remove('hidden')
        }
      }
    })
  }

  disconnect(): void {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
    if (this.autoSaveTimer) {
      clearTimeout(this.autoSaveTimer)
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
   * 创建新文章（立即保存并跳转）
   */
  // turbo-architecture-validation: disable
  async createNewDocument(): Promise<void> {
    try {
      // 获取 CSRF token
      const csrfToken = this.getCSRFToken()
      
      // 准备默认数据
      const formData = new FormData()
      formData.append('document[title]', '默认主题')
      formData.append('document[content]', '# 默认主题\n\n开始编写您的 Markdown 文档...')
      
      // 获取当前主题 ID（如果有）
      const themeId = this.themeSelectTarget.value
      if (themeId) {
        formData.append('document[theme_id]', themeId)
      }
      
      // 发送 POST 请求创建文章
      const response = await fetch('/documents', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': csrfToken,
          'Accept': 'application/json'
        },
        body: formData
      })
      
      if (response.ok) {
        const data = await response.json()
        // 跳转到新文章的编辑页面
        window.location.href = `/documents/${data.id}/edit`
      } else {
        throw new Error('创建失败')
      }
    } catch (error) {
      console.error('创建新文章失败:', error)
      if (typeof showToast === 'function') {
        showToast('❌ 创建新文章失败，请重试', 'error')
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
      if (this.autoSaveTimer) {
        clearTimeout(this.autoSaveTimer)
      }

      // 使用 2 秒防抖
      this.autoSaveTimer = window.setTimeout(() => {
        this.performAutoSave()
      }, 2000)
    }

    this.editorTarget.addEventListener('input', triggerAutoSave)
    this.titleInputTarget.addEventListener('input', triggerAutoSave)
    this.themeSelectTarget.addEventListener('change', triggerAutoSave)
  }

  /**
   * 执行自动保存
   */
  private async performAutoSave(): Promise<void> {
    // 如果是新建文档页面，不执行自动保存
    if (this.isNewDocument && !this.documentCreated) {
      return
    }
    
    // 使用 fetch 发送静默更新
    const formData = new FormData(this.formTarget)
    formData.append('auto_save', 'true')
    
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
        console.error('自动保存失败:', `Status ${response.status} - ${response.statusText}`, errorText)
      }
    } catch (error) {
      // 只在非网络错误时记录（网络离线等情况不应显示错误）
      if (error instanceof Error && error.message !== 'Failed to fetch') {
        console.error('自动保存错误:', error.message, error)
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
