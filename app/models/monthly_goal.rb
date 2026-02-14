class MonthlyGoal < ApplicationRecord
  belongs_to :user

  validates :year, presence: true, numericality: { only_integer: true, greater_than: 2000 }
  validates :month, presence: true, numericality: { only_integer: true, in: 1..12 }
  validates :user_id, uniqueness: { scope: [:year, :month], message: "already has a goal for this month" }
end
