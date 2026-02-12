# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# IMPORTANT: Do NOT add Administrator data here!
# Administrator accounts should be created manually by user.
# This seeds file is only for application data (products, categories, etc.)
#
require 'open-uri'

# Write your seed data here

puts "Creating built-in themes..."

# 定义所有内置主题（顺序与 WeMD 一致）
themes_data = [
  { name: "默认主题", files: ["basic.css", "custom-default.css", "code-github.css"] },
  { name: "学术论文", files: ["basic.css", "academic-paper.css", "code-github.css"] },
  { name: "极光玻璃", files: ["basic.css", "aurora-glass.css", "code-github.css"] },
  { name: "包豪斯", files: ["basic.css", "bauhaus.css", "code-github.css"] },
  { name: "赛博朋克", files: ["basic.css", "cyberpunk-neon.css", "code-github.css"] },
  { name: "知识库", files: ["basic.css", "knowledge-base.css", "code-github.css"] },
  { name: "李笑来原版", files: ["basic.css", "lixiaolai-classic.css", "code-github.css"] },
  { name: "黑金奢华", files: ["basic.css", "luxury-gold.css", "code-github.css"] },
  { name: "莫兰迪森林", files: ["basic.css", "morandi-forest.css", "code-github.css"] },
  { name: "新粗野主义", files: ["basic.css", "neo-brutalism.css", "code-github.css"] },
  { name: "购物小票", files: ["basic.css", "receipt.css", "code-github.css"] },
  { name: "落日胶片", files: ["basic.css", "sunset-film.css", "code-github.css"] },
  { name: "主题模板", files: ["basic.css", "template.css", "code-github.css"] }
]

themes_data.each do |theme_data|
  Theme.find_or_create_by!(name: theme_data[:name], is_builtin: true) do |theme|
    # 合并多个主题文件（basic.css + 主题特定样式 + code-github.css）
    css_content = theme_data[:files].map do |file|
      File.read(Rails.root.join('app/assets/themes', file))
    end.join("\n\n")
    
    theme.css = css_content
  end
end

puts "✓ Created #{Theme.builtin.count} built-in themes"

# 创建演示文章（为第一个用户）
puts "Creating demo document..."

# 确保至少有一个用户存在
if User.any?
  demo_user = User.first
  
  # 演示文章内容（包含所有 Markdown 格式）
  demo_content = <<~MARKDOWN
    # 欢迎使用红中排版系统

    这是一篇包含所有 Markdown 格式的演示文章。

    ## 二级标题

    ### 三级标题

    #### 四级标题

    ## 文本样式

    这是 **粗体文本**，这是 *斜体文本*，这是 ***粗斜体文本***。

    这是 ~~删除线~~。

    ## 列表

    ### 无序列表

    - 列表项 1
    - 列表项 2
      - 嵌套列表项 2.1
      - 嵌套列表项 2.2
    - 列表项 3

    ### 有序列表

    1. 第一项
    2. 第二项
    3. 第三项

    ### 任务列表

    - [x] 已完成的任务
    - [ ] 未完成的任务
    - [ ] 另一个待办事项

    ## 引用

    > 这是一段引用文字。
    >
    > 引用可以包含多个段落。

    ## 代码

    行内代码：`const message = 'Hello World'`

    ### 代码块

    ```javascript
    function greet(name) {
      console.log(`Hello, ${name}!`)
      return true
    }

    greet('World')
    ```

    ```python
    def fibonacci(n):
        if n <= 1:
            return n
        return fibonacci(n-1) + fibonacci(n-2)

    print(fibonacci(10))
    ```

    ## 链接和图片

    [访问 GitHub](https://github.com)

    ![示例图片](https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800&h=400&fit=crop)

    ## 表格

    | 姓名 | 年龄 | 职业 |
    |------|------|--------|
    | 张三 | 28   | 工程师 |
    | 李四 | 32   | 设计师 |
    | 王五 | 25   | 产品经理 |

    ## 数学公式

    行内公式：$E = mc^2$

    块级公式：

    $$
    \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}
    $$

    ## Mermaid 图表

    ### 流程图

    ```mermaid
    graph TD
        A[开始] --> B{判断条件}
        B -->|是| C[执行操作]
        B -->|否| D[结束]
        C --> D
    ```

    ### 时序图

    ```mermaid
    sequenceDiagram
        participant 用户
        participant 系统
        用户->>系统: 发送请求
        系统-->>用户: 返回响应
    ```

    ## 分隔线

    ---

    ## 总结

    以上就是所有常用的 Markdown 格式演示。祝你使用愉快！
  MARKDOWN

  # 查找或创建演示文章（使用 slug 'welcome' 作为标识）
  demo_doc = demo_user.documents.find_or_initialize_by(slug: 'welcome')
  
  if demo_doc.new_record?
    demo_doc.assign_attributes(
      title: "欢迎使用红中排版系统",
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
