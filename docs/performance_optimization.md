# JavaScript 性能优化指南

## 当前状态

- **开发模式**: 31MB (未压缩 + inline sourcemap)
- **生产模式**: 预计 5-8MB (压缩后)

## 立即优化（生产部署前必做）

### 1. 使用生产构建命令

在部署到生产环境前，运行：

```bash
npm run build:js:prod
```

这会启用 minify 压缩，文件大小减少约 **75-80%**。

### 2. 配置 Rails 资源压缩

确保 `config/environments/production.rb` 已启用 gzip：

```ruby
config.assets.compress = true
config.assets.js_compressor = :uglifier  # 或 :terser
config.public_file_server.headers = {
  'Cache-Control' => 'public, max-age=31536000',
  'Content-Encoding' => 'gzip'
}
```

### 3. CDN 部署

将 `app/assets/builds/*.js` 上传到 CDN（如 Cloudflare、AWS CloudFront），利用：
- 全球边缘节点
- 自动压缩（Brotli/Gzip）
- 长期缓存

## 长期优化（可选）

### 1. 按需加载重型库

**当前问题**: Mermaid、KaTeX、Highlight.js 在页面加载时就全部引入，但可能很多页面不需要。

**解决方案**: 动态导入

```typescript
// 仅在需要时加载 Mermaid
if (document.querySelector('.mermaid-chart')) {
  import('mermaid').then(({ default: mermaid }) => {
    mermaid.initialize({ /* config */ })
    mermaid.run()
  })
}
```

### 2. 代码分割

将 Markdown 编辑器相关功能独立打包：

```bash
# 创建单独的编辑器 bundle
esbuild app/javascript/editor.ts \
  --bundle \
  --outfile=app/assets/builds/editor.js \
  --splitting
```

### 3. 移除未使用的 Highlight.js 语言

Highlight.js 包含 200+ 语言支持，你可能只需要 10 种：

```typescript
// 替换 base.ts 中的 import
import hljs from 'highlight.js/lib/core'
import javascript from 'highlight.js/lib/languages/javascript'
import ruby from 'highlight.js/lib/languages/ruby'
// ... 只导入需要的语言

hljs.registerLanguage('javascript', javascript)
hljs.registerLanguage('ruby', ruby)
```

## 性能测试

部署后使用 Google PageSpeed Insights 测试：
- https://pagespeed.web.dev/

目标：
- FCP (First Contentful Paint) < 1.8s
- LCP (Largest Contentful Paint) < 2.5s
- TTI (Time to Interactive) < 3.8s

## 监控

添加 Performance API 监控：

```typescript
window.addEventListener('load', () => {
  const perfData = performance.getEntriesByType('navigation')[0]
  console.log('Page Load Time:', perfData.loadEventEnd - perfData.fetchStart)
})
```
