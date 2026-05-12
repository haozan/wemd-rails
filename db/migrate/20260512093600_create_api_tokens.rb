class CreateApiTokens < ActiveRecord::Migration[7.2]
  def change
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :name, null: false                # 用户给 token 起的名字（如 "QingClaw skill"）
      t.string :token_digest, null: false        # 真实 token 的 SHA256，便于唯一查找
      t.string :token_prefix, null: false        # 展示用前缀（如 wemd_abc12345...）
      t.datetime :last_used_at
      t.string :last_used_ip
      t.timestamps
    end

    add_index :api_tokens, :token_digest, unique: true
  end
end
