Rails.application.routes.draw do
  # OpenAPI/Swagger
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # メインのヘルスチェックエンドポイント
  get "healthz" => "health#check"

  # 以前のRailsデフォルトヘルスチェックはカスタムエンドポイントにリダイレクト
  get "up" => redirect("/healthz", status: 301)

  # API エンドポイント
  namespace :api do
    namespace :v1 do
      resource :auth, only: [] do
        post :register
        post :login
        post :refresh, action: :refresh_token
      end

      # チケット予約関連
      resources :ticket_reservations, only: [:create]

      # イベント関連
      resources :events, only: [:index, :show] do
        resources :tickets, only: [:index], controller: "event_tickets"
      end

      # ユーザー関連
      namespace :user do
        resources :reservations, only: [:index]
      end
    end
  end

  # 本番環境ではルート情報を無効化
  unless ENV["RAILS_SKIP_ROUTES"] == "true"
    # Rails 8.0.2では直接Rails::InfoControllerをマウントする代わりに、
    # infoコントローラーにアクセスできるように設定
    get "/rails/info" => "rails/info#index" if Rails.env.development?
    get "/rails/info/routes" => "rails/info#routes" if Rails.env.development?
    get "/rails/info/properties" => "rails/info#properties" if Rails.env.development?
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
