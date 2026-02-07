// markdown-it 自定义插件：标题包裹器
// 将标题内容包裹为 <span class="prefix"></span><span class="content">...</span><span class="suffix"></span>
// 这样可以让主题通过 CSS 在 prefix/suffix 上添加装饰元素

import type MarkdownIt from 'markdown-it'

/**
 * 标题包裹插件
 * 将 h1-h6 标题内容包裹为三个 span，使主题可以添加装饰效果
 */
export default function markdownItHeadingWrapper(md: MarkdownIt): void {
  // 保存原始的 heading_open 渲染器
  const defaultHeadingOpen = md.renderer.rules.heading_open || 
    ((tokens, idx, options, _env, self) => self.renderToken(tokens, idx, options))

  // 重写 heading_open：输出开始标签和 prefix span
  md.renderer.rules.heading_open = (tokens, idx, options, env, self) => {
    const token = tokens[idx]
    return `<${token.tag}><span class="prefix"></span><span class="content">`
  }

  // 重写 heading_close：输出 suffix span 和闭合标签
  md.renderer.rules.heading_close = (tokens, idx) => {
    const token = tokens[idx]
    return `</span><span class="suffix"></span></${token.tag}>`
  }
}
