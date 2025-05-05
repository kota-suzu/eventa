class User < ApplicationRecord
  has_secure_password

  # role を enum として定義
  enum :role, {guest: 0, organizer: 1, admin: 2}, default: :guest

  # バリデーション
  validates :email, presence: true,
    format: {with: URI::MailTo::EMAIL_REGEXP},
    uniqueness: {case_sensitive: false}
  validates :name, presence: true, length: {maximum: 50}
  validates :password, presence: true,
    length: {minimum: 8, maximum: 72},
    if: -> { password.present? || new_record? }

  # アソシエーション
  has_many :events, dependent: :destroy  # 主催者が削除されたらイベントも削除
  has_many :participants, dependent: :destroy
  has_many :participating_events, through: :participants, source: :event
  has_many :reservations, dependent: :destroy  # ユーザーが削除されたら予約も削除

  # クラスメソッド：メールアドレスとパスワードによる認証(簡略化)
  def self.authenticate(email, password)
    user = find_by(email: email)
    return nil unless user
    user.authenticate(password) ? user : nil
  end
end
