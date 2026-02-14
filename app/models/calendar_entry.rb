class CalendarEntry < ApplicationRecord
  belongs_to :user
  belongs_to :document
  
  validates :calendar_date, presence: true
  validates :document_id, uniqueness: { scope: :calendar_date, message: "已经添加到该日期" }
  
  # 按日期分组
  scope :by_date, -> { order(calendar_date: :asc) }
end
