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
