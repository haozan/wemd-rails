class AddHistoryFieldsToDocuments < ActiveRecord::Migration[7.2]
  def change
    add_column :documents, :is_auto_save, :boolean, default: false, null: false
    add_column :documents, :saved_at, :datetime
  end
end
