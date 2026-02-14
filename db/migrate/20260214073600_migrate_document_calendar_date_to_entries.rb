class MigrateDocumentCalendarDateToEntries < ActiveRecord::Migration[7.2]
  def up
    # 将现有的 document.calendar_date 数据迁移到 calendar_entries 表
    Document.where.not(calendar_date: nil).find_each do |document|
      CalendarEntry.create!(
        user_id: document.user_id,
        document_id: document.id,
        calendar_date: document.calendar_date
      )
    end
    
    # 删除 documents 表的 calendar_date 列
    remove_column :documents, :calendar_date
  end
  
  def down
    # 回滚时恢复 calendar_date 列
    add_column :documents, :calendar_date, :date
    
    # 将数据迁移回去（只保留每个文档的第一个日期）
    CalendarEntry.find_each do |entry|
      document = Document.find_by(id: entry.document_id)
      document.update_column(:calendar_date, entry.calendar_date) if document && document.calendar_date.nil?
    end
  end
end
