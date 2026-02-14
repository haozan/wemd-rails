class AddCalendarDateToDocuments < ActiveRecord::Migration[7.2]
  def change
    add_column :documents, :calendar_date, :date

  end
end
