Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # メインのヘルスチェックエンドポイント
  get "healthz" => "health#check"
  
  # 以前のRailsデフォルトヘルスチェックはカスタムエンドポイントにリダイレクト
  get "up" => redirect("/healthz", status: 301)

  # 本番環境ではルート情報を無効化
  unless ENV["RAILS_SKIP_ROUTES"] == "true"
    mount Rails::InfoController.to_app => "/rails/info" if Rails.env.development?
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
