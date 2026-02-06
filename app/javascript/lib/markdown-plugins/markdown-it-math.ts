import katex from 'katex'
import type MarkdownIt from 'markdown-it'
import type StateInline from 'markdown-it/lib/rules_inline/state_inline'
import type StateBlock from 'markdown-it/lib/rules_block/state_block'
import type Token from 'markdown-it/lib/token'

const escapeHtml = (str: string) =>
  str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')

// 测试是否为潜在的开始或结束定界符
function isValidDelim(state: StateInline, pos: number) {
  const max = state.posMax
  let can_open = true
  let can_close = true

  const prevChar = pos > 0 ? state.src.charCodeAt(pos - 1) : -1
  const nextChar = pos + 1 <= max ? state.src.charCodeAt(pos + 1) : -1

  // 检查开头和结尾的非空白条件，并且
  // 检查结束定界符后面没有跟数字
  if (
    prevChar === 0x20 /* " " */ ||
    prevChar === 0x09 /* \t */ ||
    (nextChar >= 0x30 /* "0" */ && nextChar <= 0x39) /* "9" */
  ) {
    can_close = false
  }
  if (nextChar === 0x20 /* " " */ || nextChar === 0x09 /* \t */) {
    can_open = false
  }

  return {
    can_open: can_open,
    can_close: can_close,
  }
}

// 处理行内数学公式 $...$
function math_inline(state: StateInline, silent: boolean) {
  if (state.src[state.pos] !== '$') {
    return false
  }

  const res = isValidDelim(state, state.pos)
  if (!res.can_open) {
    if (!silent) {
      state.pending += '$'
    }
    state.pos += 1
    return true
  }

  const start = state.pos + 1
  let match = start
  
  // 查找结束定界符
  while ((match = state.src.indexOf('$', match)) !== -1) {
    let pos = match - 1
    while (state.src[pos] === '\\') {
      pos -= 1
    }

    // 偶数个转义符，发现潜在的结束定界符
    if ((match - pos) % 2 === 1) {
      break
    }
    match += 1
  }

  // 未找到结束定界符
  if (match === -1) {
    if (!silent) {
      state.pending += '$'
    }
    state.pos = start
    return true
  }

  // 检查空内容
  if (match - start === 0) {
    if (!silent) {
      state.pending += '$$'
    }
    state.pos = start + 1
    return true
  }

  // 检查有效的结束定界符
  const endRes = isValidDelim(state, match)
  if (!endRes.can_close) {
    if (!silent) {
      state.pending += '$'
    }
    state.pos = start
    return true
  }

  if (!silent) {
    const token = state.push('math_inline', 'math', 0)
    token.markup = '$'
    token.content = state.src.slice(start, match)
  }

  state.pos = match + 1
  return true
}

// 处理块级数学公式 $$...$$
function math_block(
  state: StateBlock,
  start: number,
  end: number,
  silent: boolean,
) {
  let pos = state.bMarks[start] + state.tShift[start]
  const max = state.eMarks[start]

  if (pos + 2 > max) {
    return false
  }
  if (state.src.slice(pos, pos + 2) !== '$$') {
    return false
  }

  pos += 2
  let firstLine = state.src.slice(pos, max)

  if (silent) {
    return true
  }

  let found = false
  
  if (firstLine.trim().slice(-2) === '$$') {
    // 单行表达式
    firstLine = firstLine.trim().slice(0, -2)
    found = true
  }

  let next = start
  let lastLine = ''
  
  for (next = start; !found; ) {
    next++

    if (next >= end) {
      break
    }

    pos = state.bMarks[next] + state.tShift[next]
    const max = state.eMarks[next]

    if (pos < max && state.tShift[next] < state.blkIndent) {
      break
    }

    if (state.src.slice(pos, max).trim().slice(-2) === '$$') {
      const lastPos = state.src.slice(0, max).lastIndexOf('$$')
      lastLine = state.src.slice(pos, lastPos)
      found = true
    }
  }

  state.line = next + 1

  const token = state.push('math_block', 'math', 0)
  token.block = true
  token.content =
    (firstLine && firstLine.trim() ? firstLine + '\n' : '') +
    state.getLines(start + 1, next, state.tShift[start], true) +
    (lastLine && lastLine.trim() ? lastLine : '')
  token.map = [start, state.line]
  token.markup = '$$'
  return true
}

export default (md: MarkdownIt, options: any = {}) => {
  // 行内公式渲染器
  const katexInline = function (latex: string) {
    try {
      const rendered = katex.renderToString(latex, {
        displayMode: false,
        throwOnError: false,
      })
      return `<span class="inline-equation">${rendered}</span>`
    } catch (error) {
      if (options.throwOnError) {
        throw error
      }
      return `<span class="inline-equation">${escapeHtml(latex)}</span>`
    }
  }

  const inlineRenderer = function (tokens: Token[], idx: number) {
    return katexInline(tokens[idx].content)
  }

  // 块级公式渲染器
  const katexBlock = function (latex: string) {
    try {
      const rendered = katex.renderToString(latex, {
        displayMode: true,
        throwOnError: false,
      })
      return `<div class="block-equation">${rendered}</div>`
    } catch (error) {
      if (options.throwOnError) {
        throw error
      }
      return `<div class="block-equation">${escapeHtml(latex)}</div>`
    }
  }

  const blockRenderer = function (tokens: Token[], idx: number) {
    return katexBlock(tokens[idx].content) + '\n'
  }

  // 注册规则
  md.inline.ruler.after('escape', 'math_inline', math_inline)
  md.block.ruler.after('blockquote', 'math_block', math_block, {
    alt: ['paragraph', 'reference', 'blockquote', 'list'],
  })
  md.renderer.rules.math_inline = inlineRenderer
  md.renderer.rules.math_block = blockRenderer
}
