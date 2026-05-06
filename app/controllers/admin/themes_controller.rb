class Admin::ThemesController < Admin::BaseController
  before_action :set_theme, only: [:show, :edit, :update, :destroy]

  def index
    @themes = Theme.page(params[:page]).per(10)
  end

  def show
  end

  def new
    @theme = Theme.new
  end

  def create
    @theme = Theme.new(theme_params)

    if @theme.save
      redirect_to admin_theme_path(@theme), notice: 'Theme was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @theme.update(theme_params)
      redirect_to admin_theme_path(@theme), notice: 'Theme was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @theme.destroy
    redirect_to admin_themes_path, notice: 'Theme was successfully deleted.'
  end

  def sync
    # 只保留李笑来原版（唯一内置主题）
    themes_data = [
      { name: "李笑来原版", files: ["basic.css", "lixiaolai-classic.css", "code-github.css"] }
    ]

    synced_count = 0
    themes_data.each do |theme_data|
      theme = Theme.find_or_initialize_by(name: theme_data[:name], is_builtin: true)
      
      # 合并多个主题文件
      css_content = theme_data[:files].map do |file|
        file_path = Rails.root.join('app/assets/themes', file)
        File.read(file_path)
      end.join("\n\n")
      
      theme.css = css_content
      theme.save!
      synced_count += 1
    end

    redirect_to admin_root_path, notice: "成功同步 #{synced_count} 个内置主题"
  rescue => e
    redirect_to admin_root_path, alert: "主题同步失败: #{e.message}"
  end

  private

  def set_theme
    @theme = Theme.find(params[:id])
  end

  def theme_params
    params.require(:theme).permit(:name, :css, :is_builtin, :user_id)
  end
end
