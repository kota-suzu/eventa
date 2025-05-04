module Api
  skip_before_action :authenticate_user, only: [:login, :register]
  module V1
    class AuthsController < ApplicationController
      # 認証をスキップ - 新規登録とログインは認証不要
      skip_before_action :authenticate_user, only: [:register, :login]

      # POST /api/v1/auth/register
      def register
        @user = User.new(user_params)

        if @user.save
          token = generate_jwt_token(@user)
          # Cookie にも保存
          set_jwt_cookie(token)

          render json: {
            user: user_response(@user),
            token: token
          }, status: :created
        else
          render json: {
            errors: @user.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/auth/login
      def login
        @user = User.authenticate(params[:email], params[:password])

        if @user
          token = generate_jwt_token(@user)
          # Cookie にも保存
          set_jwt_cookie(token)

          render json: {
            user: user_response(@user),
            token: token
          }
        else
          render json: {
            error: I18n.t("auth.invalid_credentials")
          }, status: :unauthorized
        end
      end

      private

      def user_params
        params.require(:user).permit(:name, :email, :password, :password_confirmation, :bio, :role)
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
