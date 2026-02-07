class AddIndexesToDocuments < ActiveRecord::Migration[7.2]
  def change
    add_index :documents, [:user_id, :saved_at], order: { saved_at: :desc }
    add_index :documents, [:user_id, :is_auto_save, :saved_at]
  end
end
