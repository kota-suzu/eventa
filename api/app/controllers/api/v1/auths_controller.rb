# frozen_string_literal: true

module Api
  module V1
    class AuthsController < ApplicationController
      # 認証をスキップ - 新規登録とログインは認証不要
      skip_before_action :authenticate_user, only: [:register, :login, :refresh_token]

      # TODO(!security!urgent): レート制限を実装して、ブルートフォース攻撃を防止
      # ログインやパスワードリセット機能に対して、IPアドレスベースのレート制限を実装。
      # 失敗回数に応じて遅延や一時的なブロックを行う機能も追加する。

      # POST /api/v1/auth/register
      def register
        @user = User.new(user_params)

        if @user.save
          # アクセストークンとリフレッシュトークンを生成
          token = generate_jwt_token(@user)
          refresh_token, _ = JsonWebToken.generate_refresh_token(@user.id)

          # Cookieにも保存
          set_jwt_cookie(token)
          set_refresh_token_cookie(refresh_token)

          # ユーザーのセッション情報を保存（通常はRedisなどに保存）
          # SessionManager.save_session(user_id: @user.id, session_id: session_id)

          render json: {
            user: user_response(@user),
            token: token,
            refresh_token: refresh_token
          }, status: :created
        else
          render json: {
            errors: @user.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/auth/login
      def login
        user = User.find_by(email: auth_params[:email])

        # TODO(!security): レート制限を実装して、ブルートフォース攻撃を防止
        # 同一IPアドレスからの連続失敗回数を制限する
        # - Rackの制限ミドルウェアか、Redisベースの実装を検討
        # - 失敗回数に応じて遅延を増加させる仕組みを導入

        if user&.authenticate(auth_params[:password])
          # アクセストークンとリフレッシュトークンを発行
          token, refresh_token, _ = issue_tokens(user)

          # 成功レスポンスを返す
          render json: {
            token: token,
            refresh_token: refresh_token,
            user: UserSerializer.new(user).as_json
          }, status: :ok
        else
          # 認証失敗
          render json: {error: "無効なメールアドレスまたはパスワードです"}, status: :unauthorized
        end
      end

      # POST /api/v1/auth/refresh
      def refresh_token
        # リフレッシュトークンを取得
        refresh_token = extract_refresh_token
        Rails.logger.debug "リフレッシュトークン処理開始: #{refresh_token.present? ? "取得済み" : "未取得"}"

        if refresh_token.blank?
          Rails.logger.debug "リフレッシュトークンが見つかりません"
          return render_token_error("リフレッシュトークンが見つかりません")
        end

        payload = validate_refresh_token(refresh_token)
        return if payload.nil? # エラーレスポンスは既にvalidate_refresh_tokenで返されています

        user = find_user_from_payload(payload)
        return if user.nil? # エラーレスポンスは既にfind_user_from_payloadで返されています

        # 新しいアクセストークンを生成して返す
        issue_new_token(user)
      end

      # トークンリフレッシュ処理
      def refresh
        refresh_token = params[:refresh_token]

        begin
          decoded_token = JsonWebToken.decode(refresh_token)

          # リフレッシュトークンの検証
          if decoded_token["token_type"] != "refresh"
            return render json: {error: "無効なトークンタイプです"}, status: :unauthorized
          end

          user = User.find(decoded_token["user_id"])
          token, new_refresh_token, _ = issue_tokens(user)

          render json: {
            token: token,
            refresh_token: new_refresh_token,
            user: UserSerializer.new(user).as_json
          }, status: :ok
        rescue JWT::DecodeError, ActiveRecord::RecordNotFound
          render json: {error: "リフレッシュトークンが無効です"}, status: :unauthorized
        end
      end

      # TODO(!feature): ソーシャルログイン機能の実装
      # OAuth2ベースのソーシャルログイン（Google、GitHub、Twitterなど）を追加。
      # 既存アカウントとの連携機能も含める。

      # ログアウト処理
      def logout
        # 現在のアクセストークンをブラックリストに追加
        token = extract_current_token
        if token.present?
          TokenBlacklistService.add(token, "logout")
          Rails.logger.info "Token blacklisted for user ID: #{@current_user_id}"
        end

        # リフレッシュトークンを取得して削除
        refresh_token = extract_refresh_token
        if refresh_token.present?
          TokenBlacklistService.remove_refresh_token(refresh_token)
          Rails.logger.info "Refresh token removed for user ID: #{@current_user_id}"
        end

        # Cookieからトークンを削除
        delete_auth_cookies

        render json: {message: "ログアウトしました"}, status: :ok
      end

      private

      def validate_refresh_token(token)
        # リフレッシュトークンをデコード
        payload = JsonWebToken.safe_decode(token)
        Rails.logger.debug "デコード結果: #{payload.inspect}"

        if payload.nil?
          Rails.logger.debug "トークンのデコードに失敗しました"
          render_token_error("無効なリフレッシュトークン")
          return nil
        end

        if payload["token_type"] != "refresh"
          Rails.logger.debug "トークンタイプが不正: #{payload["token_type"]}"
          render_token_error("無効なリフレッシュトークン")
          return nil
        end

        payload
      end

      def find_user_from_payload(payload)
        # ユーザーが存在するか確認
        user = User.find_by(id: payload["user_id"])

        if user.nil?
          Rails.logger.debug "ユーザーが見つかりません: ID #{payload["user_id"]}"
          render_token_error("ユーザーが見つかりません")
          return nil
        end

        user
      end

      def issue_new_token(user)
        # 新しいアクセストークンを生成
        new_token = generate_jwt_token(user)
        Rails.logger.debug "新しいトークンを生成しました"

        # Cookieに新しいトークンを設定
        set_jwt_cookie(new_token)

        render json: {
          token: new_token,
          user: user_response(user)
        }
      end

      def render_token_error(message)
        render json: {error: message}, status: :unauthorized
      end

      def user_params
        param_format = determine_param_format
        extract_user_params(param_format)
      end

      # パラメータのフォーマットを判定
      def determine_param_format
        if params[:auth] && params[:auth][:user].present?
          :nested_user
        elsif params[:auth].present? && params[:auth].key?(:name)
          :direct_auth
        else
          :root_level
        end
      end

      # フォーマットに応じたユーザーパラメータの抽出
      def extract_user_params(format)
        permitted_attrs = [:name, :email, :password, :password_confirmation, :bio, :role]

        case format
        when :nested_user
          params.require(:auth).require(:user).permit(*permitted_attrs)
        when :direct_auth
          params.require(:auth).permit(*permitted_attrs)
        else
          params.permit(*permitted_attrs)
        end
      end

      def auth_params
        params.require(:auth).permit(:email, :password)
      end

      def generate_jwt_token(user)
        # JsonWebTokenサービスを使用
        JsonWebToken.encode({user_id: user.id})
      end

      def set_jwt_cookie(token)
        cookies.signed[:jwt] = {
          value: token,
          httponly: true,
          secure: Rails.env.production?,
          same_site: :lax,
          expires: 24.hours.from_now
        }
      end

      def set_refresh_token_cookie(token)
        cookies.signed[:refresh_token] = {
          value: token,
          httponly: true,
          secure: Rails.env.production?,
          same_site: :lax,
          expires: 30.days.from_now
        }
      end

      def extract_refresh_token
        # Cookieからリフレッシュトークンを取得
        token_from_cookie = cookies.signed[:refresh_token]
        return token_from_cookie if token_from_cookie.present?

        # ヘッダーからも取得可能にする
        header = request.headers["X-Refresh-Token"]
        return header if header.present?

        # ボディからも取得可能にする
        params[:refresh_token]
      end

      def user_response(user)
        {
          id: user.id,
          name: user.name,
          email: user.email,
          bio: user.bio,
          role: user.role,
          created_at: user.created_at
        }
      end

      # トークン発行プロセス
      def issue_tokens(user)
        # アクセストークンの作成
        payload = {user_id: user.id}
        token = JsonWebToken.encode(payload)

        # リフレッシュトークンの作成
        refresh_token, session_id = JsonWebToken.generate_refresh_token(user.id)

        # TODO(!security): セッション管理テーブルへの保存
        # ユーザーのセッション情報（デバイス、IP、トークンの失効状態）を
        # データベースに保存して管理する

        [token, refresh_token, session_id]
      end

      # 現在のJWTトークンを取得
      def extract_current_token
        header = request.headers["Authorization"]
        token_from_header = extract_token_from_header(header)
        token_from_header || cookies.signed[:jwt]
      end

      # Cookie認証情報の削除
      def delete_auth_cookies
        cookies.delete(:jwt)
        cookies.delete(:refresh_token)
      end
    end
  end
end
