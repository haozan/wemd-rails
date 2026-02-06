// markdown-it-table-container 插件
// 为表格添加滚动容器

import type MarkdownIt from 'markdown-it'

interface StateCore {
  tokens: any[]
  Token: any
}

interface Token {
  type: string
  attrs?: [string, string][]
  attrGet?: (name: string) => string | null
}

function makeRule() {
  return function addTableContainer(state: StateCore) {
    const tokens: Token[] = []
    let isTable = false

    for (let i = 0; i < state.tokens.length; i++) {
      const curToken = state.tokens[i]

      if (curToken.type === 'table_open') {
        isTable = true
        const containerOpen = new state.Token('container_div_open', 'div', 1)
        containerOpen.attrs = [['class', 'table-container']]
        tokens.push(containerOpen)
        tokens.push(curToken)
        continue
      }

      if (curToken.type === 'table_close' && isTable) {
        isTable = false
        tokens.push(curToken)
        const containerClose = new state.Token('container_div_close', 'div', -1)
        tokens.push(containerClose)
        continue
      }

      tokens.push(curToken)
    }

    state.tokens = tokens
  }
}

export default function markdownItTableContainer(md: MarkdownIt): void {
  md.core.ruler.push('table-container', makeRule())
  
  // 添加渲染规则
  md.renderer.rules.container_div_open = function(tokens, idx) {
    const token = tokens[idx]
    const className = token.attrGet('class') || ''
    return `<div class="${className}">`
  }
  
  md.renderer.rules.container_div_close = function() {
    return '</div>'
  }
}
