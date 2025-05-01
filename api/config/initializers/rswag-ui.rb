Rswag::Ui.configure do |c|
  # Swagger UIのホスティングパス
  c.openapi_endpoint "/api-docs/v1/swagger.yaml", "eventa API V1 Documentation"

  # ドキュメントのタイトル設定
  # 注: swagger_ui_titleは非推奨になりました
  # タイトルはopenapi_endpointの第2引数で指定するか、直接YAMLファイルで設定します

  # バージョン選択機能（複数のバージョンがある場合）
  # c.openapi_endpoint "/api-docs/v2/swagger.yaml", "API V2 Documentation"

  # 追加設定オプション
  c.config_object[:docExpansion] = "list" # "none", "list", or "full"
  c.config_object[:defaultModelsExpandDepth] = 1
  c.config_object[:deepLinking] = true # URLに状態を保存
  c.config_object[:displayOperationId] = false
  c.config_object[:filter] = true # 検索フィルター有効化

  # OAuthサポート（必要な場合）
  # c.config_object[:oauth2RedirectUrl] = "/api-docs/o2c.html"
end
