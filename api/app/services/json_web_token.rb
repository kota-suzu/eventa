class JsonWebToken
  # 秘密鍵を確実に文字列として取得
  SECRET_KEY = Rails.configuration.x.jwt[:secret]
  # デフォルト有効期限
  TOKEN_EXPIRY = Rails.configuration.x.jwt[:expiration] || 24.hours
  # アルゴリズム
  ALGORITHM = "HS256"

  # TODO(!security!urgent): アルゴリズムをHS256からより強力なRS256に変更する
  # 現在使用しているHS256アルゴリズムはシークレットキーを共有する必要があり、
  # より安全なRS256（RSA署名＋SHA-256）に移行する必要がある。
  # 鍵ペア（秘密鍵/公開鍵）の生成と管理方法も実装すること。

  # アプリケーション識別子（発行者）
  ISSUER = Rails.application.credentials.jwt_issuer || "eventa-api-#{Rails.env}"
  # 想定される受信者（サービス名）
  AUDIENCE = Rails.application.credentials.jwt_audience || "eventa-client"

  # TODO(!security): トークンリボケーション（失効）の仕組みを追加
  # ログアウト時やパスワード変更時などに既存トークンを無効化できる仕組みを実装。
  # Redisベースのブラックリストかデータベーステーブルでの管理を検討。

  # TODO(!feature): トークン更新（リフレッシュ）フローの最適化
  # リフレッシュトークンの発行・検証・更新フローを最適化し、
  # トークンの再利用検知や不正アクセス防止機能を強化する。

  # TODO(!security): JWT有効期限管理の強化
  # アクセストークンとリフレッシュトークンの有効期限を環境・重要度に応じて設定できるよう
  # 柔軟な有効期限管理を実装する。

  # TODO(!feature): デバイス情報を含めた多要素認証対応
  # トークンにデバイス情報（フィンガープリント）を含め、不正アクセス検知の精度を向上させる。
  # 同時に多要素認証（2FA）のサポートも追加する。

  class << self
    # JWTトークンのエンコード - expを自動付与
    def encode(payload, exp = TOKEN_EXPIRY)
      payload = payload.dup
      add_security_claims(payload, exp)
      JWT.encode(payload, SECRET_KEY, ALGORITHM)
    end

    # セキュリティクレームを追加（標準クレームと有効期限）
    def add_security_claims(payload, exp)
      add_standard_claims(payload)
      add_expiry_claim(payload, exp)
    end

    # 標準的なセキュリティクレームを追加
    def add_standard_claims(payload)
      now = Time.current.to_i
      payload[:iss] = ISSUER            # 発行者
      payload[:aud] = AUDIENCE          # 対象者
      payload[:iat] = now               # 発行時刻
      payload[:nbf] = now               # 有効開始時刻
      payload[:jti] = SecureRandom.uuid # 一意のトークンID
    end

    # 有効期限クレームを追加
    def add_expiry_claim(payload, exp)
      payload[:exp] = calculate_expiry(exp)
    end

    # OPTIMIZE: JWTの署名と検証処理のパフォーマンス最適化
    # 現在の実装は都度計算しているが、頻繁に使用される処理なので改善の余地あり
    # - キャッシュ層の導入
    # - ハードウェアアクセラレーションの活用（可能な場合）

    # 有効期限を計算
    def calculate_expiry(exp)
      determine_expiry_strategy(exp)
    end

    # 型に基づいて適切な有効期限計算戦略を決定
    def determine_expiry_strategy(exp)
      return expiry_from_duration(exp) if exp.is_a?(ActiveSupport::Duration)
      return expiry_from_time_object(exp) if time_object?(exp)
      return expiry_from_numeric(exp) if numeric?(exp)

      expiry_default
    end

    # 時間オブジェクトかどうかを判定
    def time_object?(obj)
      obj.is_a?(Time) || obj.is_a?(DateTime)
    end

    # 数値型かどうかを判定
    def numeric?(obj)
      obj.is_a?(Integer) || obj.is_a?(Float)
    end

    # Durationから有効期限を計算
    def expiry_from_duration(duration)
      duration.from_now.to_i
    end

    # TimeオブジェクトからUnixタイムスタンプを取得
    def expiry_from_time_object(time_obj)
      time_obj.to_i
    end

    # 数値からUnixタイムスタンプを取得
    def expiry_from_numeric(numeric)
      numeric.to_i
    end

    # デフォルトの有効期限を返す
    def expiry_default
      TOKEN_EXPIRY.from_now.to_i
    end

    # JWTトークンのデコード
    def decode(token)
      validate_token_presence(token)
      decode_token_with_options(token)
    rescue JWT::DecodeError => e
      handle_decode_error(e)
    end

    # トークンの存在チェック
    def validate_token_presence(token)
      raise JWT::DecodeError, "Token cannot be blank" if token.blank?
    end

    # 設定されたオプションでトークンをデコード
    def decode_token_with_options(token)
      JWT.decode(
        token,
        SECRET_KEY,
        true,
        decode_options
      )[0]
    end

    # デコードオプションの生成
    def decode_options
      {
        algorithm: ALGORITHM,
        verify_iss: true,
        iss: ISSUER,
        verify_aud: true,
        aud: AUDIENCE,
        verify_iat: true,
        leeway: 30 # 30秒の時間差を許容
      }
    end

    # デコードエラーのハンドリング
    def handle_decode_error(error)
      log_decode_error(error)
      raise error
    end

    # デコードエラーのログ出力
    def log_decode_error(error)
      log_specific_error(error)
    end

    # エラータイプに応じたログ記録
    def log_specific_error(error)
      error_logger = determine_error_logger(error)
      error_logger.call(error)
    end

    # エラータイプに応じたロガーを決定
    def determine_error_logger(error)
      error_loggers = {
        JWT::ExpiredSignature => method(:log_expired_token_error),
        JWT::InvalidIssuerError => method(:log_invalid_issuer_error),
        JWT::InvalidAudError => method(:log_invalid_audience_error)
      }

      error_loggers.fetch(error.class) { method(:log_general_decode_error) }
    end

    # 有効期限切れエラーのログ出力
    def log_expired_token_error(error)
      Rails.logger.info "JWT token expired: #{error.message}"
    end

    # 不正な発行者エラーのログ出力
    def log_invalid_issuer_error(error)
      Rails.logger.info "Invalid JWT issuer: #{error.message}"
    end

    # 不正な対象者エラーのログ出力
    def log_invalid_audience_error(error)
      Rails.logger.info "Invalid JWT audience: #{error.message}"
    end

    # その他のデコードエラーのログ出力
    def log_general_decode_error(error)
      Rails.logger.info "JWT decode error: #{error.message}"
    end

    # コントローラーなどの実際の認証処理で使用するメソッド
    def safe_decode(token)
      return nil if token.blank?
      handle_safe_decode(token)
    end

    # 安全なデコード処理の実装
    def handle_safe_decode(token)
      decode(token)
    rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError => e
      log_decode_error_for_safe_decode(e)
      nil
    end

    # 安全なデコード処理のためのエラーログ記録
    def log_decode_error_for_safe_decode(error)
      Rails.logger.info "JWT decode error: #{error.message}"
    end

    # リフレッシュトークンの生成（ユーザーIDと一意のセッションIDを含む）
    def generate_refresh_token(user_id = nil)
      session_id = SecureRandom.hex(32)
      return session_id if user_id.nil?

      create_refresh_token(user_id, session_id)
    end

    # TODO(!feature): デバイス情報を含めた多要素認証対応
    # リフレッシュトークン生成時にデバイス情報を含め、
    # 不審なデバイスからのアクセス時に追加認証を要求する機能

    # リフレッシュトークンの作成処理
    def create_refresh_token(user_id, session_id)
      refresh_exp = Rails.configuration.x.jwt[:refresh_expiration] || 30.days
      payload = build_refresh_payload(user_id, session_id)
      token = encode(payload, refresh_exp)
      [token, session_id]
    end

    # リフレッシュトークン用のペイロード構築
    def build_refresh_payload(user_id, session_id)
      {
        user_id: user_id,
        session_id: session_id,
        token_type: "refresh"
      }
    end
  end
end
