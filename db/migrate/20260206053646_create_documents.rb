class CreateDocuments < ActiveRecord::Migration[7.2]
  def change
    create_table :documents do |t|
      t.string :title
      t.text :content
      t.integer :theme_id
      t.integer :user_id
      t.string :slug


      t.timestamps
    end
  end
end
