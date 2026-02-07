class Document < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  belongs_to :user
  belongs_to :theme, optional: true

  validates :title, presence: true, length: { maximum: 200 }
  validates :content, presence: true

  # 默认按保存时间倒序
  scope :recent, -> { order(saved_at: :desc, updated_at: :desc) }
  scope :history_entries, -> { where(is_auto_save: false).recent }
  scope :auto_saved, -> { where(is_auto_save: true).recent }

  # 在保存时设置 saved_at 时间戳
  before_save :set_saved_at, if: :will_save_change_to_content?

  # 限制用户历史记录数量
  MAX_HISTORY_ENTRIES = 30

  # 清理超过限制的历史记录
  def self.cleanup_old_entries(user)
    entries = user.documents.history_entries.offset(MAX_HISTORY_ENTRIES)
    entries.destroy_all if entries.any?
  end

  # 获取或创建用户的演示文章
  def self.find_or_create_welcome_document(user)
    # 首先尝试查找用户的演示文章（通过 slug 'welcome' 和 user_id）
    welcome_doc = user.documents.find_by(slug: 'welcome')
    
    return welcome_doc if welcome_doc.present?
    
    # 如果不存在，创建新的演示文章
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
    
    # 创建演示文章
    welcome_doc = user.documents.create!(
      title: "欢迎使用红中排版系统",
      content: demo_content,
      theme_id: Theme.builtin.first&.id,
      is_auto_save: false,
      slug: 'welcome'
    )
    
    welcome_doc
  end

  private

  def set_saved_at
    self.saved_at = Time.current
  end
end
