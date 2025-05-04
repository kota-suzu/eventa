class ApplicationController < ActionController::API
  include ActionController::Cookies

  # デフォルトで全アクションに認証を要求
  before_action :authenticate_user

  private

  # 認証が必要なコントローラーで使用するメソッド
  def authenticate_user
    token = extract_token
    return render_unauthorized(I18n.t("errors.auth.missing_token")) if token.blank?

    payload = JsonWebToken.decode(token)
    return render_unauthorized(I18n.t("errors.auth.invalid_token")) unless payload

    @current_user = User.find_by(id: payload["user_id"])
    render_unauthorized(I18n.t("errors.auth.user_not_found")) unless @current_user
  end

  # authenticate_user のエイリアスメソッド（コントローラー内で使いやすいように）
  # 既存のDeviseメソッドとの混同を避けるため明示的にprivateにする
  alias_method :authenticate_user!, :authenticate_user
  private :authenticate_user!

  # 現在のユーザーを取得
  attr_reader :current_user

  # リクエストからJWTトークンを抽出
  def extract_token
    # Cookieからトークンを取得（優先）
    token_from_cookie = cookies.signed[:jwt]
    return token_from_cookie if token_from_cookie.present?

    # 従来のヘッダーからの取得もサポート（後方互換性のため）
    header = request.headers["Authorization"]
    header&.split(" ")&.last
  end

  def render_unauthorized(message = nil)
    render json: {error: message || I18n.t("errors.unauthorized")}, status: :unauthorized
  end
end
