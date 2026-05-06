class Admin::DashboardController < Admin::BaseController
  def index
    @admin_count = Administrator.all.size
    @recent_logs = AdminOplog.includes(:administrator).order(created_at: :desc).limit(5)

    @show_password_change_modal = current_admin&.first_login? && Rails.env.production?
  end

  def reinitialize_themes
    # 定义所有内置主题（与 seeds.rb 保持一致）
    themes_data = [
      { name: "默认主题", files: ["basic.css", "lixiaolai-classic.css", "code-github.css"] },
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

    updated_count = 0
    themes_data.each do |theme_data|
      theme = Theme.find_or_initialize_by(name: theme_data[:name], is_builtin: true)
      
      # 合并多个主题文件
      css_content = theme_data[:files].map do |file|
        file_path = Rails.root.join('app/assets/themes', file)
        File.read(file_path)
      end.join("\n\n")
      
      theme.css = css_content
      theme.save!
      updated_count += 1
    end

    # 同步 wx_style_map(jsonb):以 Wechat::ThemeStyleMaps::BY_NAME 为准
    require Rails.root.join('app/services/wechat/theme_style_maps')
    Wechat::ThemeStyleMaps::BY_NAME.each do |name, map|
      theme = Theme.builtin.find_by(name: name)
      next unless theme
      theme.update_column(:wx_style_map, map.stringify_keys)
    end

    AdminOplog.create!(
      administrator: current_admin,
      action: 'update',
      resource_type: 'Theme',
      details: "重新初始化了 #{updated_count} 个内置主题",
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )

    redirect_to admin_root_path, notice: "成功重新初始化 #{updated_count} 个内置主题"
  rescue => e
    redirect_to admin_root_path, alert: "主题初始化失败: #{e.message}"
  end

  # 只同步微信草稿渲染用的 wx_style_map (jsonb), 不碰 CSS 预览
  # 用于快速上线 wx_style_map 的代码变更, 执行快、风险低
  def sync_wx_style_maps
    require Rails.root.join('app/services/wechat/theme_style_maps')
    updated = []
    missing = []
    Wechat::ThemeStyleMaps::BY_NAME.each do |name, map|
      theme = Theme.builtin.find_by(name: name)
      if theme
        theme.update_column(:wx_style_map, map.stringify_keys)
        updated << name
      else
        missing << name
      end
    end

    AdminOplog.create!(
      administrator: current_admin,
      action: 'update',
      resource_type: 'Theme',
      details: "同步 wx_style_map: 已更新 #{updated.join('、')}#{missing.any? ? "; 未找到: #{missing.join('、')}" : ''}",
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )

    msg = "已同步 #{updated.size} 个主题的微信样式: #{updated.join('、')}"
    msg += "; ⚠ 未找到: #{missing.join('、')}" if missing.any?
    redirect_to admin_root_path, notice: msg
  rescue => e
    redirect_to admin_root_path, alert: "微信样式同步失败: #{e.message}"
  end
end
