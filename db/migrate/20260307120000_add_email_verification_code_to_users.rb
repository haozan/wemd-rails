class AddEmailVerificationCodeToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :email_verification_code, :string
    add_column :users, :email_verification_code_expires_at, :datetime
  end
end
