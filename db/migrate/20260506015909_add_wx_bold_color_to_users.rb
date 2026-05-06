class AddWxBoldColorToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :wx_bold_color, :string

  end
end
