require "factory_bot"

# 「FactoryBot初期化設定が適用されました」メッセージを出力
puts "FactoryBot初期化設定が適用されました"

RSpec.configure do |config|
  # FactoryBotのメソッドを直接使用可能に
  config.include FactoryBot::Syntax::Methods

  # テストスイート実行前に一度だけファクトリをロード
  config.before(:suite) do
    # すでにロードされている定義をクリア(バージョン6.x対応)
    if FactoryBot.respond_to?(:factories)
      FactoryBot.factories.clear
    end

    # 定義ファイルのパスを明示的に指定
    factories_path = File.join(Rails.root, "spec", "factories")
    warn "ファクトリーパス: #{factories_path}"

    # ファクトリーファイルを直接要求
    Dir[File.join(factories_path, "**", "*.rb")].sort.each do |factory_file|
      warn "ファクトリーファイル読み込み: #{factory_file}"
      require factory_file
    end
  rescue => e
    puts "エラー: FactoryBot初期化中に問題が発生しました: #{e.message}"
    puts e.backtrace.join("\n")
  end

  # テスト間でファクトリオブジェクトのキャッシュをクリア
  config.after(:each) do
    FactoryBot.rewind_sequences if FactoryBot.respond_to?(:rewind_sequences)
  end
end

# シンプルな設定だけを適用
FactoryBot.use_parent_strategy = false if FactoryBot.respond_to?(:use_parent_strategy)
