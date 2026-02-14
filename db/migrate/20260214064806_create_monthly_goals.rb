class CreateMonthlyGoals < ActiveRecord::Migration[7.2]
  def change
    create_table :monthly_goals do |t|
      t.references :user
      t.integer :year
      t.integer :month
      t.text :goal_content


      t.timestamps
    end
  end
end
