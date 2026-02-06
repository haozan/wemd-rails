class CreateThemes < ActiveRecord::Migration[7.2]
  def change
    create_table :themes do |t|
      t.string :name
      t.text :css
      t.boolean :is_builtin, default: false
      t.integer :user_id


      t.timestamps
    end
  end
end
