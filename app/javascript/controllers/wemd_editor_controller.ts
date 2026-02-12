import { Controller } from "@hotwired/stimulus"
import { parseMarkdown, applyTheme } from "../lib/markdown_parser"
import juice from 'juice'

export default class extends Controller<HTMLElement> {
  static targets = [
    "form",
    "titleInput",
    "editor",
    "preview",
    "previewContent",
    "themeSelect",
    "copyButton",
    "saveStatus",
    "footnoteNumber"
  ]

  static values = {
    themes: Array
  }

  // Declare target types
  declare readonly formTarget: HTMLFormElement
  declare readonly titleInputTarget: HTMLInputElement
  declare readonly editorTarget: HTMLTextAreaElement
  declare readonly previewTarget: HTMLElement
  declare readonly previewContentTarget: HTMLElement
  declare readonly themeSelectTarget: HTMLSelectElement
  declare readonly copyButtonTarget: HTMLButtonElement
  declare readonly saveStatusTarget: HTMLElement
  declare readonly footnoteNumberTarget: HTMLElement
  declare readonly hasCopyButtonTarget: boolean
  declare readonly hasSaveStatusTarget: boolean
  declare readonly hasPreviewContentTarget: boolean
  declare readonly hasFootnoteNumberTarget: boolean
  
  // Declare value types
  declare themesValue: Array<{ id: number; name: string; css: string }>

  private debounceTimer: number | null = null
  private autoSaveTimer: number | null = null
  private showHeadingMenu: boolean = false
  private showListMenu: boolean = false
  private headingMenuRef: HTMLElement | null = null
  private listMenuRef: HTMLElement | null = null
  private isSyncingScroll: boolean = false
  
  // 撤销/重做历史记录
  private history: Array<{ title: string; content: string }> = []
  private historyIndex: number = -1
  private isRestoringHistory: boolean = false
  private maxHistorySize: number = 100

  connect(): void {
    console.log("WeMD Editor connected")
    console.log('[WeMD Debug] Checking saveStatus target...', {
      hasSaveStatusTarget: this.hasSaveStatusTarget,
      saveStatusElement: this.hasSaveStatusTarget ? this.saveStatusTarget : null
    })
    
    // 初始化历史记录
    this.saveToHistory()
    
    this.updatePreview()
    this.setupAutoSave()
    
    // 初始化状态显示为"已保存"
    if (this.hasSaveStatusTarget) {
      console.log('[WeMD Debug] Initializing save status to "saved"')
      this.updateSaveStatus('saved')
    } else {
      console.warn('[WeMD Debug] saveStatus target not found!')
    }
    
    // 初始化脚注序号显示
    this.updateFootnoteNumber()
    
    this.setupOutsideClickHandler()
    this.setupKeyboardShortcuts()
    this.setupScrollSync()
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
    document.removeEventListener('keydown', this.handleKeyboardShortcut)
    this.editorTarget.removeEventListener('scroll', this.handleEditorScroll)
  }



  /**
   * 更新预览（防抖处理）
   */
  updatePreview(): void {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    this.debounceTimer = window.setTimeout(() => {
      this.syncFootnotes()
      this.renderPreview()
      this.updateFootnoteNumber()
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
   * 渲染后处理（代码高亮等）
   */
  private postRenderHooks(): void {
    // 未来可添加其他渲染后处理逻辑
  }

  /**
   * 撤销
   */
  undo(): void {
    if (!this.canUndo()) return
    
    this.historyIndex--
    this.restoreFromHistory()
    console.log('[WeMD Undo] Undo performed, current index:', this.historyIndex)
  }

  /**
   * 重做
   */
  redo(): void {
    if (!this.canRedo()) return
    
    this.historyIndex++
    this.restoreFromHistory()
    console.log('[WeMD Redo] Redo performed, current index:', this.historyIndex)
  }

  /**
   * 检查是否可以撤销
   */
  private canUndo(): boolean {
    return this.historyIndex > 0
  }

  /**
   * 检查是否可以重做
   */
  private canRedo(): boolean {
    return this.historyIndex < this.history.length - 1
  }

  /**
   * 保存当前状态到历史记录
   */
  private saveToHistory(): void {
    if (this.isRestoringHistory) return
    
    const currentState = {
      title: this.titleInputTarget.value,
      content: this.editorTarget.value
    }
    
    // 如果在历史记录中间进行了新的编辑，删除后面的历史
    if (this.historyIndex < this.history.length - 1) {
      this.history = this.history.slice(0, this.historyIndex + 1)
    }
    
    // 检查是否与上一个状态相同，避免重复保存
    const lastState = this.history[this.historyIndex]
    if (lastState && 
        lastState.title === currentState.title && 
        lastState.content === currentState.content) {
      return
    }
    
    this.history.push(currentState)
    this.historyIndex++
    
    // 限制历史记录大小
    if (this.history.length > this.maxHistorySize) {
      this.history.shift()
      this.historyIndex--
    }
    
    console.log('[WeMD History] State saved, index:', this.historyIndex, 'total:', this.history.length)
  }

  /**
   * 从历史记录恢复状态
   */
  private restoreFromHistory(): void {
    if (this.historyIndex < 0 || this.historyIndex >= this.history.length) return
    
    this.isRestoringHistory = true
    
    const state = this.history[this.historyIndex]
    this.titleInputTarget.value = state.title
    this.editorTarget.value = state.content
    
    // 更新预览
    this.updatePreview()
    
    // 触发自动保存（但不记录到历史）
    this.updateSaveStatus('editing')
    if (this.autoSaveTimer) {
      clearTimeout(this.autoSaveTimer)
    }
    this.autoSaveTimer = window.setTimeout(() => {
      this.performAutoSave()
    }, 2000)
    
    this.isRestoringHistory = false
  }

  /**
   * 设置键盘快捷键
   */
  private setupKeyboardShortcuts(): void {
    this.handleKeyboardShortcut = this.handleKeyboardShortcut.bind(this)
    document.addEventListener('keydown', this.handleKeyboardShortcut)
  }

  /**
   * 处理键盘快捷键
   */
  private handleKeyboardShortcut = (event: KeyboardEvent): void => {
    // 检查是否在编辑器区域
    const target = event.target as HTMLElement
    if (!this.element.contains(target)) return
    
    const isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0
    const modKey = isMac ? event.metaKey : event.ctrlKey
    
    // Ctrl+Z / Cmd+Z: 撤销
    if (modKey && event.key === 'z' && !event.shiftKey) {
      event.preventDefault()
      this.undo()
    }
    
    // Ctrl+Shift+Z / Cmd+Shift+Z: 重做
    // Ctrl+Y / Cmd+Y: 重做（Windows 风格）
    if ((modKey && event.key === 'z' && event.shiftKey) || 
        (modKey && event.key === 'y')) {
      event.preventDefault()
      this.redo()
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
    this.updateDropdownMenus()
  }

  /**
   * 插入指定级别的标题
   */
  insertHeadingLevel(event: Event): void {
    const button = event.currentTarget as HTMLElement
    const prefix = button.dataset.prefix || '## '
    const placeholder = button.dataset.placeholder || '标题'
    this.insertAtCursorPreserveSelection(prefix, placeholder)
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
    this.wrapSelection('\n```javascript\n', '\n```\n', 'console.log("Hello World")')
  }

  /**
   * 工具栏操作：切换列表菜单
   */
  toggleListMenu(event: Event): void {
    event.stopPropagation()
    this.showListMenu = !this.showListMenu
    this.showHeadingMenu = false
    this.updateDropdownMenus()
  }

  /**
   * 插入指定类型的列表
   */
  insertListType(event: Event): void {
    const button = event.currentTarget as HTMLElement
    const prefix = button.dataset.prefix || '- '
    const placeholder = button.dataset.placeholder || '列表项'
    
    // 检测是否是有序列表（前缀以数字开头）
    const isOrderedList = /^\d+\.\s/.test(prefix)
    
    this.insertAtCursorPreserveSelection(prefix, placeholder, isOrderedList)
    this.showListMenu = false
    this.updateDropdownMenus()
  }

  /**
   * 工具栏操作：插入引用
   */
  insertQuote(): void {
    this.insertAtCursorPreserveSelection('> ', '引用内容')
  }

  /**
   * 工具栏操作：插入脚注
   */
  insertFootnote(): void {
    const editor = this.editorTarget
    const start = editor.selectionStart
    const end = editor.selectionEnd
    const text = editor.value
    const selectedText = text.substring(start, end)

    // 查找当前文档中已有的脚注编号
    const footnoteMatches = text.matchAll(/\[\^(\d+)\]/g)
    const existingNumbers = Array.from(footnoteMatches).map(match => parseInt(match[1], 10))
    const nextNumber = existingNumbers.length > 0 ? Math.max(...existingNumbers) + 1 : 1

    // 在光标位置或选中文本后面插入脚注引用
    const footnoteRef = `[^${nextNumber}]`
    // 保留选中的文本，在其后面添加脚注引用
    const newText = text.substring(0, start) + selectedText + footnoteRef + text.substring(end)
    editor.value = newText

    // 移动光标到文档末尾并插入脚注定义
    const footnoteDefinition = `\n\n[^${nextNumber}]: ${selectedText || '脚注内容'}`
    editor.value = editor.value + footnoteDefinition

    // 选中脚注定义中的内容文本，方便用户编辑
    const definitionStart = editor.value.lastIndexOf(': ') + 2
    const definitionEnd = editor.value.length
    editor.setSelectionRange(definitionStart, definitionEnd)
    editor.focus()

    // 保存到历史记录
    this.saveToHistory()

    // 触发预览更新和序号更新
    this.updatePreview()
  }

  /**
   * 工具栏操作：插入表格
   */
  insertTable(): void {
    const table = `
| 表头 1 | 表头 2 | 表头 3 |
| ------- | ------- | ------- |
| 单元格 1 | 单元格 2 | 单元格 3 |
| 单元格 4 | 单元格 5 | 单元格 6 |
`
    this.insertAtCursor(table, '')
  }

  /**
   * 同步脚注：双向同步删除
   * 1. 删除脚注定义时自动删除正文中的引用
   * 2. 删除正文引用时自动删除未使用的脚注定义
   */
  private syncFootnotes(): void {
    const editor = this.editorTarget
    let text = editor.value
    let hasChanges = false
    
    // 查找所有的脚注定义 [^n]: xxx (包括整行)
    const definitionMatches = Array.from(text.matchAll(/\[\^(\d+)\]:.*(?:\n|$)/g))
    const definedNumbers = new Set(definitionMatches.map(match => match[1]))
    const definitions = definitionMatches.map(match => ({
      number: match[1],
      index: match.index!,
      length: match[0].length,
      fullText: match[0]
    }))
    
    // 查找所有的脚注引用 [^n]
    const referenceMatches = Array.from(text.matchAll(/\[\^(\d+)\](?!:)/g))
    const referencedNumbers = new Set(referenceMatches.map(match => match[1]))
    const references = referenceMatches.map(match => ({
      number: match[1],
      index: match.index!,
      length: match[0].length
    }))
    
    // 1. 找出没有定义的引用（需要删除）
    const orphanedReferences = references.filter(ref => !definedNumbers.has(ref.number))
    
    if (orphanedReferences.length > 0) {
      // 从后往前删除，避免索引偏移
      for (let i = orphanedReferences.length - 1; i >= 0; i--) {
        const ref = orphanedReferences[i]
        text = text.substring(0, ref.index) + text.substring(ref.index + ref.length)
      }
      hasChanges = true
      console.log(`[WeMD Footnote Sync] Removed ${orphanedReferences.length} orphaned footnote reference(s)`)
    }
    
    // 2. 找出没有被引用的定义（需要删除）
    const unusedDefinitions = definitions.filter(def => !referencedNumbers.has(def.number))
    
    if (unusedDefinitions.length > 0) {
      // 从后往前删除，避免索引偏移
      for (let i = unusedDefinitions.length - 1; i >= 0; i--) {
        const def = unusedDefinitions[i]
        text = text.substring(0, def.index) + text.substring(def.index + def.length)
      }
      hasChanges = true
      console.log(`[WeMD Footnote Sync] Removed ${unusedDefinitions.length} unused footnote definition(s)`)
    }
    
    // 如果有变化，更新编辑器内容
    if (hasChanges) {
      editor.value = text
      this.saveToHistory()
    }
  }

  /**
   * 更新脚注按钮上的序号显示
   */
  private updateFootnoteNumber(): void {
    if (!this.hasFootnoteNumberTarget) return

    const text = this.editorTarget.value
    const footnoteMatches = text.matchAll(/\[\^(\d+)\]/g)
    const existingNumbers = Array.from(footnoteMatches).map(match => parseInt(match[1], 10))
    const nextNumber = existingNumbers.length > 0 ? Math.max(...existingNumbers) + 1 : 1

    this.footnoteNumberTarget.textContent = `[${nextNumber}]`
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
    
    if (!clickedInsideHeading && !clickedInsideList) {
      this.showHeadingMenu = false
      this.showListMenu = false
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
  }

  /**
   * 工具方法：在光标位置插入文本（保留选中文本，支持多行处理）
   * @param prefix - 行首前缀（如 '> ', '- ', '1. ', '# ' 等）
   * @param placeholder - 占位符文本（当没有选中文本时使用）
   * @param isOrderedList - 是否是有序列表（需要自动递增序号）
   */
  private insertAtCursorPreserveSelection(prefix: string, placeholder: string, isOrderedList: boolean = false): void {
    const editor = this.editorTarget
    const start = editor.selectionStart
    const end = editor.selectionEnd
    const text = editor.value
    const selectedText = text.substring(start, end)

    let newContent: string
    let newCursorEnd: number

    if (selectedText) {
      // 如果有选中文本，处理多行
      const lines = selectedText.split('\n')
      const processedLines = lines.map((line, index) => {
        if (isOrderedList) {
          // 有序列表：自动递增序号
          const number = index + 1
          return `${number}. ${line}`
        } else {
          // 其他类型：直接添加前缀
          return `${prefix}${line}`
        }
      })
      newContent = processedLines.join('\n')
      newCursorEnd = start + newContent.length
    } else {
      // 如果没有选中文本，使用占位符
      newContent = prefix + placeholder
      newCursorEnd = start + newContent.length
    }

    // 更新编辑器内容
    const newText = text.substring(0, start) + newContent + text.substring(end)
    editor.value = newText
    
    // 设置新的光标位置
    if (selectedText) {
      // 如果有选中文本，选中新插入的内容
      editor.setSelectionRange(start, newCursorEnd)
    } else {
      // 如果没有选中文本，选中占位符
      editor.setSelectionRange(start + prefix.length, newCursorEnd)
    }
    editor.focus()

    // 保存到历史记录
    this.saveToHistory()
    
    // 触发预览更新
    this.updatePreview()
  }

  /**
   * 工具方法：在光标位置插入文本（仅用于图片上传等不需要保留选中文本的场景）
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

    // 保存到历史记录
    this.saveToHistory()
    
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

    // 保存到历史记录
    this.saveToHistory()
    
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
      
      // 保存到历史记录（用户手动输入时）
      if (!this.isRestoringHistory) {
        this.saveToHistory()
      }
      
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
   * 设置滚动同步
   */
  private setupScrollSync(): void {
    this.handleEditorScroll = this.handleEditorScroll.bind(this)
    this.editorTarget.addEventListener('scroll', this.handleEditorScroll)
  }

  /**
   * 处理编辑区滚动事件
   */
  private handleEditorScroll = (): void => {
    if (this.isSyncingScroll) return
    
    this.isSyncingScroll = true
    
    // 获取编辑区滚动百分比
    const editor = this.editorTarget
    const scrollPercentage = editor.scrollTop / (editor.scrollHeight - editor.clientHeight)
    
    // 同步到预览区
    const previewPane = this.element.querySelector('.wemd-preview-content') as HTMLElement
    if (previewPane) {
      const targetScroll = scrollPercentage * (previewPane.scrollHeight - previewPane.clientHeight)
      previewPane.scrollTop = targetScroll
    }
    
    // 重置标志
    requestAnimationFrame(() => {
      this.isSyncingScroll = false
    })
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
