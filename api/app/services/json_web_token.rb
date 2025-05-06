class JsonWebToken
  # 秘密鍵を確実に文字列として取得
  SECRET_KEY = Rails.application.credentials.secret_key_base
  # デフォルト有効期限
  TOKEN_EXPIRY = Rails.configuration.x.jwt[:expiration] || 24.hours
  # アルゴリズム
  ALGORITHM = "HS256"
  # アプリケーション識別子（発行者）
  ISSUER = Rails.application.credentials.jwt_issuer || "eventa-api-#{Rails.env}"
  # 想定される受信者（サービス名）
  AUDIENCE = Rails.application.credentials.jwt_audience || "eventa-client"

  class << self
    # JWTトークンのエンコード - expを自動付与
    def encode(payload, exp = TOKEN_EXPIRY)
      payload = payload.dup

      # セキュリティクレームを追加
      add_standard_claims(payload)

      # 期限を設定
      add_expiry_claim(payload, exp)

      JWT.encode(payload, SECRET_KEY, ALGORITHM)
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

    # 有効期限を計算
    def calculate_expiry(exp)
      if exp.is_a?(ActiveSupport::Duration)
        expiry_from_duration(exp)
      elsif exp.is_a?(Time) || exp.is_a?(DateTime)
        expiry_from_time_object(exp)
      elsif exp.is_a?(Integer) || exp.is_a?(Float)
        expiry_from_numeric(exp)
      else
        expiry_default
      end
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
      raise JWT::DecodeError, "Token cannot be blank" if token.blank?

      JWT.decode(
        token,
        SECRET_KEY,
        true,
        decode_options
      )[0]
    rescue JWT::DecodeError => e
      handle_decode_error(e)
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
      # エラータイプに応じたログ出力
      log_decode_error(error)

      # エラーの再発生
      raise error # 呼び出し元で処理できるようにエラーを再度発生させる
    end

    # デコードエラーのログ出力
    def log_decode_error(error)
      case error
      when JWT::ExpiredSignature
        log_expired_token_error(error)
      when JWT::InvalidIssuerError
        log_invalid_issuer_error(error)
      when JWT::InvalidAudError
        log_invalid_audience_error(error)
      else
        log_general_decode_error(error)
      end
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
    # テスト内部ではなく、アプリケーションコードで使用される
    def safe_decode(token)
      # トークンが空やnilの場合は早期リターン
      return nil if token.blank?

      begin
        decode(token)
      rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError => e
        # エラーログを記録
        Rails.logger.info "JWT decode error: #{e.message}"
        nil
      end
    end

    # リフレッシュトークンの生成（ユーザーIDと一意のセッションIDを含む）
    def generate_refresh_token(user_id = nil)
      session_id = SecureRandom.hex(32)

      if user_id.nil?
        return session_id
      end

      refresh_exp = Rails.configuration.x.jwt[:refresh_expiration] || 30.days

      payload = {
        user_id: user_id,
        session_id: session_id,
        token_type: "refresh"
      }

      token = encode(payload, refresh_exp)
      [token, session_id]
    end
  end
end
