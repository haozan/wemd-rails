// WeMD Markdown Parser - 基础版
// 基于 markdown-it 和相关插件

import MarkdownIt from 'markdown-it'
import markdownItDeflist from 'markdown-it-deflist'
import markdownItImplicitFigures from 'markdown-it-implicit-figures'
import markdownItTableOfContents from 'markdown-it-table-of-contents'
import markdownItRuby from 'markdown-it-ruby'
import markdownItMark from 'markdown-it-mark'
import markdownItSub from 'markdown-it-sub'
import markdownItSup from 'markdown-it-sup'
import { full as markdownItEmoji } from 'markdown-it-emoji'
import markdownItTaskLists from 'markdown-it-task-lists'
import hljs from 'highlight.js'

// 自定义插件（简化版）
import markdownItMultiquote from './markdown-plugins/markdown-it-multiquote'
import markdownItTableContainer from './markdown-plugins/markdown-it-table-container'
import markdownItMath from './markdown-plugins/markdown-it-math'
import markdownItHeadingWrapper from './markdown-plugins/markdown-it-heading-wrapper'

/**
 * 创建 Markdown 解析器实例
 */
export function createMarkdownParser(): MarkdownIt {
  const md = new MarkdownIt({
    html: true,
    linkify: true,
    typographer: true,
    highlight: (str: string, lang: string): string => {
      // Mermaid 图表：输出 pre.mermaid 让前端渲染
      if (lang === 'mermaid') {
        const escaped = md.utils.escapeHtml(str)
        return `<pre class="mermaid">\n${escaped}\n</pre>\n`
      }

      // 默认语言为 bash
      if (!lang || lang === '') {
        lang = 'bash'
      }

      // 语法高亮
      if (lang && hljs.getLanguage(lang)) {
        try {
          const formatted = hljs.highlight(str, { language: lang, ignoreIllegals: true }).value
          return `<pre class="custom"><code class="hljs">${formatted}</code></pre>`
        } catch (err) {
          console.error('Highlight.js error:', err)
        }
      }

      // 无法高亮则返回纯文本
      return `<pre class="custom"><code class="hljs">${md.utils.escapeHtml(str)}</code></pre>`
    }
  })

  // 应用插件
  md
    .use(markdownItMath, {
      throwOnError: false
    })
    .use(markdownItTableContainer)
    .use(markdownItTableOfContents, {
      transformLink: () => '',
      includeLevel: [2, 3],
      markerPattern: /^\[t o c\]/im
    })
    .use(markdownItRuby)
    .use(markdownItImplicitFigures, { figcaption: true })
    .use(markdownItDeflist)
    .use(markdownItMultiquote)
    .use(markdownItMark)
    .use(markdownItSub)
    .use(markdownItSup)
    .use(markdownItEmoji)
    .use(markdownItTaskLists, {
      enabled: true,
      label: true,
      labelAfter: true
    })
    .use(markdownItHeadingWrapper) // 标题包裹插件，必须在最后应用

  return md
}

/**
 * 解析 Markdown 文本为 HTML
 * @param markdown Markdown 文本
 * @returns HTML 字符串
 */
export function parseMarkdown(markdown: string): string {
  const parser = createMarkdownParser()
  return parser.render(markdown)
}

/**
 * 应用主题包裹到预览 HTML
 * @param html 预览 HTML
 * @returns 包裹了 #wemd 容器的 HTML
 */
export function applyTheme(html: string): string {
  // 只负责包裹内容，样式由外部的 #theme-styles 元素管理
  return `<div id="wemd">${html}</div>`
}
