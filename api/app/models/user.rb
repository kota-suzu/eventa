class User < ApplicationRecord
  has_secure_password

  # role を enum として定義
  enum :role, {guest: 0, organizer: 1, admin: 2}, default: :guest

  # TODO(!feature): ロールベースのアクセス制御（RBAC）を強化
  # 現在の単純なrole列を拡張し、より柔軟なRBACシステムを実装。
  # 権限グループやリソースベースの権限管理を追加し、管理UIも実装する。

  # TODO(!security!urgent): パスワード強度のバリデーションを強化
  # パスワードポリシーを強化し、長さ、複雑さ、一般的なパスワードリストとの照合、
  # 過去に使用したパスワードの再利用防止などの機能を追加する。

  # バリデーション
  validates :email, presence: true,
    format: {with: URI::MailTo::EMAIL_REGEXP},
    uniqueness: {case_sensitive: false}
  validates :name, presence: true, length: {maximum: 50}
  validates :password, presence: true,
    length: {minimum: 8, maximum: 72},
    if: -> { password.present? || new_record? }

  # TODO(!security): パスワード強度のバリデーションを強化
  # 現在は文字数のみの検証だが、以下の追加検証が必要：
  # - 大文字・小文字・数字・特殊文字を含む複雑性要件
  # - よく使われるパスワードの禁止（辞書チェック）
  # - 過去に使用したパスワードの再利用防止
  # - HaveIBeenPwned APIとの連携でデータ漏洩チェック

  # アソシエーション
  has_many :events, dependent: :destroy  # 主催者が削除されたらイベントも削除
  has_many :participants, dependent: :destroy
  has_many :participating_events, through: :participants, source: :event
  has_many :reservations, dependent: :destroy  # ユーザーが削除されたら予約も削除

  # TODO(!feature): 二要素認証(2FA)の実装
  # TOTPベースの2FAと、バックアップコードによるリカバリーシステムを実装。
  # 認証アプリ（Google AuthenticatorやAuthyなど）との連携をサポート。

  # アカウント状態管理
  attribute :status, :integer
  enum :status, {
    active: 0,      # 有効なアカウント
    inactive: 1,    # 無効化されたアカウント
    suspended: 2    # 一時停止されたアカウント
  }, prefix: true

  # 初期化時にデフォルト値を設定
  def initialize(attributes = nil)
    super
    self.status ||= :active
  end

  # アカウント無効化
  def deactivate
    update(status: :inactive)
  end

  # FIXME: アカウント削除処理の改善
  # 現在の物理削除から論理削除への変更
  # - 削除フラグと削除日時の追加
  # - 削除猶予期間の設定（30日間の取り消し可能期間）
  # - 関連データの適切な処理方針
  # - GDPRに準拠したデータエクスポート機能

  # ユーザー認証処理
  def self.authenticate(email, password)
    user = find_by(email: email.downcase.strip)
    return nil unless user

    # ステータスチェック
    return nil unless user.status_active?

    # パスワード検証
    user.authenticate(password) ? user : nil
  end

  # TODO(!security): アカウントロック機能の実装
  # 連続した認証失敗に対して、一定時間アカウントをロックする機能。
  # 不正アクセス検知とアラート通知システムも実装する。

  # TODO(!feature): プロフィール管理機能の拡張
  # ユーザープロフィールの詳細情報（プロフィール画像、SNSリンク、
  # 自己紹介など）を管理する機能を追加。アバター画像のアップロードと処理も実装。

  # メールアドレス正規化（保存前）
  before_save :normalize_email

  private

  def normalize_email
    self.email = email.downcase.strip if email
  end
end
