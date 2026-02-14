class CalendarsController < ApplicationController
  before_action :authenticate_user!

  def index
    @year = params[:year]&.to_i || Time.current.year
    @month = params[:month]&.to_i || Time.current.month
    
    # 获取该月的所有文章 - 使用 CalendarEntry
    @documents_by_date = get_documents_by_date(@year, @month)
    
    # 获取月度目标
    @monthly_goal = current_user.monthly_goals.find_or_initialize_by(year: @year, month: @month)
  end

  # 获取某月的文章数据（AJAX）
  def month_data
    year = params[:year].to_i
    month = params[:month].to_i
    
    documents_by_date = get_documents_by_date(year, month)
    
    render turbo_stream: turbo_stream.replace(
      "calendar-grid",
      partial: "calendars/calendar_grid",
      locals: { year: year, month: month, documents_by_date: documents_by_date }
    )
  end

  # 搜索文章
  def search_documents
    query = params[:query].to_s.strip
    documents = if query.present?
      current_user.documents.where("title LIKE ?", "%#{query}%").order(updated_at: :desc).limit(10)
    else
      current_user.documents.order(updated_at: :desc).limit(10)
    end
    
    render turbo_stream: turbo_stream.replace(
      "document-list",
      partial: "calendars/document_list",
      locals: { documents: documents }
    )
  end

  # 添加文章到日历
  def add_documents
    date = Date.parse(params[:date])
    document_ids = params[:document_ids] || []
    
    # 使用 CalendarEntry 来支持同一文章添加到多个日期
    document_ids.each do |document_id|
      # find_or_create_by 防止重复添加
      current_user.calendar_entries.find_or_create_by(
        document_id: document_id,
        calendar_date: date
      )
    end
    
    render turbo_stream: turbo_stream.replace(
      "calendar-container",
      partial: "calendars/calendar",
      locals: { 
        year: date.year, 
        month: date.month, 
        documents_by_date: get_documents_by_date(date.year, date.month),
        monthly_goal: current_user.monthly_goals.find_or_initialize_by(year: date.year, month: date.month)
      }
    )
  end

  # 移除文章
  def remove_document
    entry = current_user.calendar_entries.find_by(
      document_id: params[:document_id],
      calendar_date: Date.parse(params[:date])
    )
    entry&.destroy
    
    year = params[:year].to_i
    month = params[:month].to_i
    
    render turbo_stream: turbo_stream.replace(
      "calendar-container",
      partial: "calendars/calendar",
      locals: { 
        year: year, 
        month: month, 
        documents_by_date: get_documents_by_date(year, month),
        monthly_goal: current_user.monthly_goals.find_or_initialize_by(year: year, month: month)
      }
    )
  end

  # 保存月度目标
  def save_goal
    year = params[:year].to_i
    month = params[:month].to_i
    goal_content = params[:goal_content]
    
    goal = current_user.monthly_goals.find_or_initialize_by(year: year, month: month)
    goal.goal_content = goal_content
    
    if goal.save
      head :ok
    else
      head :unprocessable_entity
    end
  end

  private
  
  def get_documents_by_date(year, month)
    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month
    
    # 使用 CalendarEntry 来获取文章
    entries = current_user.calendar_entries
      .includes(:document)
      .where(calendar_date: start_date..end_date)
      .order(:calendar_date)
    
    # 按日期分组
    entries.group_by(&:calendar_date).transform_values do |date_entries|
      date_entries.map(&:document)
    end
  end
end
