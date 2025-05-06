class ApplicationController < ActionController::API
  include ActionController::Cookies

  # JWT認証を全アクションに適用
  before_action :authenticate_request

  # OPTIMIZE: 認証処理のパフォーマンス最適化
  # 現在のリクエストごとの認証処理を改善し、特に高頻度APIで効率化
  # - トークン検証結果のキャッシュ
  # - レート制限の効率的実装
  # - バッチ処理用の特殊認証

  # TODO(!feature!urgent): グローバルエラーハンドリングの強化
  # すべてのコントローラーで一貫したエラーレスポンスを提供するために、
  # エラーハンドリングを強化。詳細なエラーコードと多言語対応メッセージを実装。

  # エラーレスポンス用のヘルパーメソッド
  def render_error(message, status = :unprocessable_entity)
    render json: {error: message}, status: status
  end

  # 認証エラーレスポンス
  def render_unauthorized(message = "認証が必要です")
    render json: {error: message}, status: :unauthorized
  end

  # TODO(!security): IPアドレスベースの追加検証
  # 怪しいIPアドレスからのアクセスを検知・制限するシステムを実装。
  # GeoIPデータベースとの連携や、既知の悪意あるIPリストとの照合も行う。

  # TODO(!performance): レスポンスキャッシュの最適化
  # 頻繁にアクセスされるエンドポイントのレスポンスをキャッシュし、
  # パフォーマンスを向上。ETagによる条件付きリクエストもサポート。

  # TODO(!feature): APIレート制限の実装
  # すべてのAPIリクエストに対するレート制限を実装し、
  # スロットリングとクォータ管理によりサービス安定性を確保。

  private

  # リクエストの認証
  def authenticate_request
    # ヘッダーからトークン取得
    header = request.headers["Authorization"]

    # Cookieからもトークンを取得（Web向け）
    cookie_token = cookies.signed[:jwt]

    # ヘッダーまたはCookieからのトークン取得
    token = extract_token_from_header(header) || cookie_token

    # トークンがない場合は未認証エラー
    unless token
      return render_unauthorized
    end

    # ブラックリストされたトークンかどうかをチェック
    if TokenBlacklistService.blacklisted?(token)
      Rails.logger.info "Blacklisted token detected: #{request.remote_ip}"
      return render_unauthorized("このトークンは無効化されています")
    end

    begin
      # トークンをデコード
      decoded_token = JsonWebToken.decode(token)
      # ユーザーIDをコントローラから参照可能に
      @current_user_id = decoded_token["user_id"]
    rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError => e
      # トークンが無効または期限切れ
      render_unauthorized("無効なトークンです: #{e.message}")
    end
  end

  # 現在の認証済みユーザーを取得
  def current_user
    @current_user ||= User.find_by(id: @current_user_id) if @current_user_id
  end

  # Authorizationヘッダーからトークンを抽出
  def extract_token_from_header(header)
    # Bearer形式のトークンを抽出
    if header&.start_with?("Bearer ")
      header.gsub("Bearer ", "")
    end
  end

  # JWT cookieを設定
  def set_jwt_cookie(token)
    cookies.signed[:jwt] = {
      value: token,
      httponly: true,
      secure: Rails.env.production?,
      expires: 24.hours.from_now
    }
  end

  # リフレッシュトークンcookieを設定
  def set_refresh_token_cookie(refresh_token)
    cookies.signed[:refresh_token] = {
      value: refresh_token,
      httponly: true,
      secure: Rails.env.production?,
      expires: 30.days.from_now
    }
  end

  # FIXME: CSRFトークン検証の実装
  # APIでもステートフルセッションを使用する場合は、
  # CSRF対策が必要
  # - トークンの生成と検証メカニズム
  # - 特定エンドポイントでの検証
end
