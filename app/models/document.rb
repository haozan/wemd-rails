class Document < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  belongs_to :user
  belongs_to :theme, optional: true

  validates :title, presence: true, length: { maximum: 200 }
  validates :content, presence: true

  # 默认按更新时间倒序
  scope :recent, -> { order(updated_at: :desc) }
end
