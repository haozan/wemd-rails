# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# IMPORTANT: Do NOT add Administrator data here!
# Administrator accounts should be created manually by user.
# This seeds file is only for application data (products, categories, etc.)

puts "Creating built-in themes..."

# 只保留李笑来原版主题（唯一内置主题）
themes_data = [
  { name: "李笑来原版", files: ["basic.css", "lixiaolai-classic.css", "code-github.css"] }
]

themes_data.each do |theme_data|
  # 合并多个主题文件
  css_content = theme_data[:files].map do |file|
    File.read(Rails.root.join('app/assets/themes', file))
  end.join("\n\n")

  theme = Theme.find_or_initialize_by(name: theme_data[:name], is_builtin: true)
  theme.css = css_content
  theme.save!
end

# 同步 wx_style_map(jsonb):真源在 Wechat::ThemeStyleMaps::BY_NAME,始终以最新 Ruby 常量为准
require Rails.root.join('app/services/wechat/theme_style_maps')
Wechat::ThemeStyleMaps::BY_NAME.each do |name, map|
  theme = Theme.builtin.find_by(name: name)
  next unless theme
  theme.update_column(:wx_style_map, map.stringify_keys)
end
puts "✓ Synced wx_style_map for #{Wechat::ThemeStyleMaps::BY_NAME.size} theme(s)"

puts "✓ Created #{Theme.builtin.count} built-in themes"

# 创建演示文章（为第一个用户）
puts "Creating demo document..."

if User.any?
  demo_user = User.first

  demo_content = <<~MARKDOWN
    # 欢迎使用 WeMD 编辑器

    这是一篇演示文章，包含常用 Markdown 格式。

    ## 文本样式

    这是 **粗体文本**，这是 *斜体文本*。

    ## 列表

    - 列表项 1
    - 列表项 2
    - 列表项 3

    ## 代码

    行内代码：`const message = 'Hello World'`

    ```javascript
    function greet(name) {
      console.log(`Hello, ${name}!`)
    }
    ```

    ## 引用

    > 这是一段引用文字。

    ## 表格

    | 姓名 | 职业 |
    |------|------|
    | 张三 | 工程师 |
    | 李四 | 设计师 |
  MARKDOWN

  demo_doc = demo_user.documents.find_or_initialize_by(slug: 'welcome')

  if demo_doc.new_record?
    demo_doc.assign_attributes(
      title: "欢迎使用 WeMD 编辑器",
      content: demo_content,
      theme_id: Theme.builtin.first&.id,
      is_auto_save: false
    )
    demo_doc.save!
    puts "✓ Created demo document: #{demo_doc.title}"
  else
    puts "✓ Demo document already exists: #{demo_doc.title}"
  end
else
  puts "⚠ No users found, skipping demo document creation"
end
