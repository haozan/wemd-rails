class Admin::DashboardController < Admin::BaseController
  def index
    @admin_count = Administrator.all.size
    @recent_logs = AdminOplog.includes(:administrator).order(created_at: :desc).limit(5)

    @show_password_change_modal = current_admin&.first_login? && Rails.env.production?
  end

  def reinitialize_themes
    # 只保留李笑来原版（唯一内置主题）
    themes_data = [
      { name: "李笑来原版", files: ["basic.css", "lixiaolai-classic.css", "code-github.css"] }
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
