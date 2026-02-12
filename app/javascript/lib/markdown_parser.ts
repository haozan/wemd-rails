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
import markdownItFootnote from 'markdown-it-footnote'
import hljs from 'highlight.js'

// 自定义插件（简化版）
import markdownItMultiquote from './markdown-plugins/markdown-it-multiquote'
import markdownItTableContainer from './markdown-plugins/markdown-it-table-container'
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
    .use(markdownItTableContainer)
    .use(markdownItFootnote) // 脚注插件
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

  // 自定义脚注渲染规则 - 在脚注说明前添加序号显示
  md.renderer.rules.footnote_block_open = () => (
    '<h3>References</h3>\n' +
    '<section class="footnotes">\n' +
    '<ol class="footnotes-list">\n'
  )

  md.renderer.rules.footnote_block_close = () => (
    '</ol>\n' +
    '</section>\n'
  )

  md.renderer.rules.footnote_open = (tokens, idx) => {
    const id = Number(tokens[idx].meta.id + 1)
    return `<li id="fn${id}" class="footnote-item"><span class="footnote-num">[${id}]</span>`
  }

  md.renderer.rules.footnote_close = () => {
    return '</li>\n'
  }

  md.renderer.rules.footnote_anchor = () => {
    return ''
  }

  // 移除脚注内容中的 <p> 标签，让序号和说明在同一行
  const defaultParagraphOpen = md.renderer.rules.paragraph_open || ((tokens, idx, options, _env, self) => self.renderToken(tokens, idx, options))
  const defaultParagraphClose = md.renderer.rules.paragraph_close || ((tokens, idx, options, _env, self) => self.renderToken(tokens, idx, options))

  md.renderer.rules.paragraph_open = (tokens, idx, options, env, self) => {
    // 如果是在脚注内部，不输出 <p> 标签
    const token = tokens[idx]
    if (token.level > 0) {
      // 检查是否在 footnote 环境中
      for (let i = idx - 1; i >= 0; i--) {
        if (tokens[i].type === 'footnote_open') {
          return ''
        }
        if (tokens[i].type === 'footnote_close') {
          break
        }
      }
    }
    return defaultParagraphOpen(tokens, idx, options, env, self)
  }

  md.renderer.rules.paragraph_close = (tokens, idx, options, env, self) => {
    // 如果是在脚注内部，不输出 </p> 标签
    const token = tokens[idx]
    if (token.level > 0) {
      // 检查是否在 footnote 环境中
      for (let i = idx - 1; i >= 0; i--) {
        if (tokens[i].type === 'footnote_open') {
          return ''
        }
        if (tokens[i].type === 'footnote_close') {
          break
        }
      }
    }
    return defaultParagraphClose(tokens, idx, options, env, self)
  }

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
 * @param inlineStyles 是否内联样式（用于复制到微信）
 * @returns 包裹了 #wemd 容器的 HTML
 */
export function applyTheme(html: string, inlineStyles: boolean = false): string {
  // 为顶级块元素添加 data-tool 属性（微信公众号要求）
  const DATA_TOOL = 'WeMD编辑器'
  const BLOCK_TAGS = ['p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li', 'blockquote', 'table', 'figure', 'pre', 'hr']
  
  let processedHtml = html
  
  if (inlineStyles) {
    // 保护代码块中的空格，防止微信清洗时删除
    processedHtml = processedHtml.replace(
      /<code([^>]*class="[^"]*\bhljs\b[^"]*"[^>]*)>([\s\S]*?)<\/code>/g,
      (_match, attrs: string, inner: string) => {
        let protected_ = inner
        // 将制表符转换为4个空格
        protected_ = protected_.replace(/\t/g, '    ')
        // 将行首和中间的空格转换为不间断空格
        protected_ = protected_.replace(/\n( +)/g, (_m, spaces: string) => {
          return `\n${'&#160;'.repeat(spaces.length)}`
        })
        protected_ = protected_.replace(/^( +)/, (_m, spaces: string) => {
          return '&#160;'.repeat(spaces.length)
        })
        return `<code${attrs}>${protected_}</code>`
      }
    )
    
    // 为块元素添加 data-tool 属性
    BLOCK_TAGS.forEach((tag) => {
      const regex = new RegExp(`<${tag}(\\s+[^>]*|)>`, 'gi')
      processedHtml = processedHtml.replace(regex, (match, attributes) => {
        if (match.includes('data-tool=')) return match
        return `<${tag} data-tool="${DATA_TOOL}"${attributes}>`
      })
    })
  }
  
  // 包裹在 section#wemd 中
  // 复制到微信时添加透明背景防止浏览器保留选区背景色
  const tagName = inlineStyles ? 'section' : 'div'
  const bgStyle = inlineStyles ? ' style="background:transparent;background-color:transparent;"' : ''
  return `<${tagName} id="wemd"${bgStyle}>${processedHtml}</${tagName}>`
}
