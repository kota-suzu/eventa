# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # 開発環境ではすべてのオリジンを許可（デバッグ用）
    origins "*"

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: false # originが"*"の場合はfalseにする必要がある
  end

  # credentialsを使用する場合は個別のオリジンを指定
  if Rails.env.development?
    allow do
      # コンテナ内および開発環境からのアクセスを許可
      origins "localhost:3000", "127.0.0.1:3000", "frontend:3000", "host.docker.internal:3000"

      resource "*",
        headers: :any,
        methods: [:get, :post, :put, :patch, :delete, :options, :head],
        credentials: true
    end
  end
end
