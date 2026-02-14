class CreateCalendarEntries < ActiveRecord::Migration[7.2]
  def change
    create_table :calendar_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.date :calendar_date, null: false

      t.timestamps
    end
    
    # 防止同一文章在同一天重复添加
    add_index :calendar_entries, [:document_id, :calendar_date], unique: true, name: 'index_calendar_entries_on_document_and_date'
    # 优化按日期查询
    add_index :calendar_entries, [:user_id, :calendar_date]
  end
end
