# factory_botの初期化設定
if defined?(FactoryBot) && Rails.env.test?
  # テスト環境でのみ適用
  require "factory_bot"

  # 自動ロード機能を無効化
  FactoryBot.allow_class_lookup = false if FactoryBot.respond_to?(:allow_class_lookup=)

  # 自動検索パスを明示的に空にして自動ロードを防ぐ
  FactoryBot.definition_file_paths = [] if FactoryBot.respond_to?(:definition_file_paths=)

  # 起動時に既存のファクトリを初期化
  FactoryBot.factories.clear if FactoryBot.respond_to?(:factories)

  puts "FactoryBot初期化設定が適用されました"
end
