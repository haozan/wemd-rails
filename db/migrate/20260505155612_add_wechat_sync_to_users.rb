class AddWechatSyncToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :wechat_app_id, :string
    add_column :users, :wechat_app_secret, :string

  end
end
