class Document < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  belongs_to :user
  belongs_to :theme, optional: true

  validates :title, presence: true, length: { maximum: 200 }
  validates :content, presence: true

  # 默认按保存时间倒序
  scope :recent, -> { order(saved_at: :desc, updated_at: :desc) }
  scope :history_entries, -> { where(is_auto_save: false).recent }
  scope :auto_saved, -> { where(is_auto_save: true).recent }

  # 在保存时设置 saved_at 时间戳
  before_save :set_saved_at, if: :will_save_change_to_content?

  # 限制用户历史记录数量
  MAX_HISTORY_ENTRIES = 30

  # 清理超过限制的历史记录
  def self.cleanup_old_entries(user)
    entries = user.documents.history_entries.offset(MAX_HISTORY_ENTRIES)
    entries.destroy_all if entries.any?
  end

  private

  def set_saved_at
    self.saved_at = Time.current
  end
end
