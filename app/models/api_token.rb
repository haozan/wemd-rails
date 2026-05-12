require 'digest'

class ApiToken < ApplicationRecord
  belongs_to :user

  validates :name, presence: true, length: { maximum: 50 }
  validates :token_digest, presence: true, uniqueness: true
  validates :token_prefix, presence: true

  TOKEN_PREFIX = 'wemd_'.freeze

  # 生成一个新 token，明文只在创建时返回，DB 里只存 SHA256 摘要
  # 用法:
  #   record, plain_token = ApiToken.issue!(user, name: 'QingClaw skill')
  def self.issue!(user, name:)
    plain = "#{TOKEN_PREFIX}#{SecureRandom.hex(20)}"  # wemd_<40 chars>
    record = create!(
      user: user,
      name: name,
      token_digest: digest_for(plain),
      token_prefix: plain[0, 12]                       # 前 12 位用于在列表中识别
    )
    [record, plain]
  end

  # 用明文 token 找 record（鉴权用）
  def self.authenticate(plain)
    return nil if plain.blank?
    find_by(token_digest: digest_for(plain))
  end

  def self.digest_for(plain)
    Digest::SHA256.hexdigest(plain.to_s)
  end

  def touch_usage!(ip:)
    update_columns(last_used_at: Time.current, last_used_ip: ip)
  end
end
