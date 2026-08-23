# frozen_string_literal: true

class AddWxTypographyProfileToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :wx_typography_profile, :string,
               default: 'readable_17', null: false
  end
end
