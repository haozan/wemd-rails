class AddWxStyleMapToThemes < ActiveRecord::Migration[7.2]
  def change
    add_column :themes, :wx_style_map, :jsonb

  end
end
