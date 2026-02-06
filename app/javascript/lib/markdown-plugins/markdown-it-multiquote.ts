// markdown-it-multiquote 插件
// 为嵌套引用添加层级 class

import type MarkdownIt from 'markdown-it'

interface StateCore {
  tokens: any[]
}

interface Token {
  type: string
  attrs?: [string, string][]
}

function makeRule() {
  return function addMultiquoteClass(state: StateCore) {
    let count = 0
    let outerQuoteToken: Token | undefined

    for (let i = 0; i < state.tokens.length; i++) {
      const curToken = state.tokens[i]
      
      if (curToken.type === 'blockquote_open') {
        if (count === 0) {
          // 最外层 blockquote 的 token
          outerQuoteToken = curToken
        }
        count++
        continue
      }

      if (count > 0 && outerQuoteToken) {
        outerQuoteToken.attrs = [['class', `multiquote-${count}`]]
        count = 0
      }
    }
  }
}

export default function markdownItMultiquote(md: MarkdownIt): void {
  md.core.ruler.push('blockquote-class', makeRule())
}
