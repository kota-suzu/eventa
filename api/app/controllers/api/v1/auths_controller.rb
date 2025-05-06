# frozen_string_literal: true

module Api
  module V1
    class AuthsController < ApplicationController
      # 認証をスキップ - 新規登録とログインは認証不要
      skip_before_action :authenticate_user, only: [:register, :login, :refresh_token]

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
        # authハッシュからのパラメータとルートレベルの両方をサポート
        email = auth_params[:email]
        password = auth_params[:password]

        @user = User.authenticate(email, password)

        if @user
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
          }, status: :ok
        else
          render json: {
            error: I18n.t("auth.invalid_credentials")
          }, status: :unauthorized
        end
      end

      # POST /api/v1/auth/refresh
      def refresh_token
        # リフレッシュトークンを取得
        refresh_token = extract_refresh_token

        # デバッグログ
        Rails.logger.debug "リフレッシュトークン処理開始: #{refresh_token.present? ? "取得済み" : "未取得"}"

        if refresh_token.blank?
          Rails.logger.debug "リフレッシュトークンが見つかりません"
          return render json: {error: "リフレッシュトークンが見つかりません"}, status: :unauthorized
        end

        # リフレッシュトークンをデコード
        payload = JsonWebToken.safe_decode(refresh_token)
        Rails.logger.debug "デコード結果: #{payload.inspect}"

        if payload.nil?
          Rails.logger.debug "トークンのデコードに失敗しました"
          return render json: {error: "無効なリフレッシュトークン"}, status: :unauthorized
        end

        if payload["token_type"] != "refresh"
          Rails.logger.debug "トークンタイプが不正: #{payload["token_type"]}"
          return render json: {error: "無効なリフレッシュトークン"}, status: :unauthorized
        end

        # ユーザーが存在するか確認
        user = User.find_by(id: payload["user_id"])

        if user.nil?
          Rails.logger.debug "ユーザーが見つかりません: ID #{payload["user_id"]}"
          return render json: {error: "ユーザーが見つかりません"}, status: :unauthorized
        end

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

      private

      def user_params
        # ユーザーパラメータがauthハッシュ内にネストされている場合の対応
        if params[:auth] && params[:auth][:user].present?
          params.require(:auth).require(:user).permit(:name, :email, :password, :password_confirmation, :bio, :role)
        elsif params[:auth].present? && params[:auth].key?(:name)
          # authハッシュ内に直接ユーザー情報がある場合
          params.require(:auth).permit(:name, :email, :password, :password_confirmation, :bio, :role)
        else
          # 従来通りのパラメータ形式
          params.permit(:name, :email, :password, :password_confirmation, :bio, :role)
        end
      end

      def auth_params
        # authハッシュがある場合はそれを使い、なければルートレベルのパラメータを使用
        if params[:auth].present?
          params.require(:auth).permit(:email, :password, :remember)
        else
          params.permit(:email, :password, :remember)
        end
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
    end
  end
end
