class AddWxPrimaryColorToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :wx_primary_color, :string, default: '#1e6bb8', limit: 7
  end
end
