// Type declarations for markdown-it and its plugins without official types

// Global functions (full type declaration in types/global.d.ts)
declare function showToast(message: string, type?: 'success' | 'error' | 'info' | 'warning' | 'danger', position?: 'top-right' | 'top-center' | 'top-left', duration?: number): void

declare module 'markdown-it-deflist' {
  import type MarkdownIt from 'markdown-it'
  const markdownItDeflist: MarkdownIt.PluginSimple
  export default markdownItDeflist
}

declare module 'markdown-it-implicit-figures' {
  import type MarkdownIt from 'markdown-it'
  const markdownItImplicitFigures: MarkdownIt.PluginSimple
  export default markdownItImplicitFigures
}

declare module 'markdown-it-table-of-contents' {
  import type MarkdownIt from 'markdown-it'
  const markdownItTableOfContents: MarkdownIt.PluginWithOptions
  export default markdownItTableOfContents
}

declare module 'markdown-it-ruby' {
  import type MarkdownIt from 'markdown-it'
  const markdownItRuby: MarkdownIt.PluginSimple
  export default markdownItRuby
}

declare module 'markdown-it-mark' {
  import type MarkdownIt from 'markdown-it'
  const markdownItMark: MarkdownIt.PluginSimple
  export default markdownItMark
}

declare module 'markdown-it-sub' {
  import type MarkdownIt from 'markdown-it'
  const markdownItSub: MarkdownIt.PluginSimple
  export default markdownItSub
}

declare module 'markdown-it-sup' {
  import type MarkdownIt from 'markdown-it'
  const markdownItSup: MarkdownIt.PluginSimple
  export default markdownItSup
}

declare module 'markdown-it-emoji' {
  import type MarkdownIt from 'markdown-it'
  export const full: MarkdownIt.PluginSimple
  export const light: MarkdownIt.PluginSimple
  export const bare: MarkdownIt.PluginSimple
}

declare module 'markdown-it-task-lists' {
  import type MarkdownIt from 'markdown-it'
  const markdownItTaskLists: MarkdownIt.PluginWithOptions
  export default markdownItTaskLists
}
