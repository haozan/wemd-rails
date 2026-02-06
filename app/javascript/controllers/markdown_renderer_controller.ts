import { Controller } from "@hotwired/stimulus"
import { parseMarkdown } from "../lib/markdown_parser"

export default class extends Controller<HTMLElement> {
  static values = {
    content: String
  }

  declare readonly contentValue: string

  connect(): void {
    console.log("MarkdownRenderer connected")
    this.renderMarkdown()
  }

  /**
   * 渲染 Markdown 内容
   */
  private renderMarkdown(): void {
    if (!this.contentValue || this.contentValue.trim() === '') {
      this.element.innerHTML = "<p class='text-muted-foreground'>暂无内容</p>"
      return
    }

    try {
      const html = parseMarkdown(this.contentValue)
      this.element.innerHTML = html
      
      // 触发代码高亮和其他渲染后处理
      this.postRenderHooks()
    } catch (error) {
      console.error('Markdown rendering failed:', error)
      this.element.innerHTML = "<p class='text-red-500'>渲染失败，请重新加载页面</p>"
    }
  }

  /**
   * 渲染后处理（Mermaid 图表等）
   */
  private postRenderHooks(): void {
    // 如果有 Mermaid 图表，初始化它们
    // stimulus-validator: disable-next-line
    const mermaidBlocks = this.element.querySelectorAll('.mermaid')
    if (mermaidBlocks.length > 0 && window.mermaid) {
      window.mermaid.init(undefined, mermaidBlocks as NodeListOf<HTMLElement>)
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
