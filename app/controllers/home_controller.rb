class HomeController < ApplicationController
  include HomeDemoConcern

  def index
    # 显示落地页，所有用户都可以访问
  end
end
