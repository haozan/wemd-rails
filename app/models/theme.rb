class Theme < ApplicationRecord
  belongs_to :user, optional: true
  has_many :documents, dependent: :nullify

  validates :name, presence: true, length: { maximum: 100 }
  validates :css, presence: true

  # 内置主题不属于任何用户
  scope :builtin, -> { where(is_builtin: true) }
  scope :custom, -> { where(is_builtin: false) }

  # 获取用户可用的主题（内置主题 + 用户自定义主题）
  scope :available_for_user, ->(user) {
    where(is_builtin: true).or(where(user: user))
  }
end
