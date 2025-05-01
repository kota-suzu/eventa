Rswag::Api.configure do |c|
  # ベースパスの指定（Swagger UIのURLになります）
  c.openapi_root = Rails.root.join("docs/swagger").to_s

  # カスタムリクエストプロセッサーの設定（必要に応じて）
  # c.request_headers = { 'X-API-Key': 'api_key_for_test' }

  # CORS設定
  c.swagger_filter = lambda { |swagger, env| swagger }
end
