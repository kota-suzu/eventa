# テストカバレッジを計測するためのヘルパーファイル
# テスト実行時に自動的に読み込まれ、カバレッジ計測を設定します

require 'simplecov'
require 'simplecov-lcov'

# テストカバレッジレポートにLCOV形式も追加（CI/CD連携用）
SimpleCov::Formatter::LcovFormatter.config do |c|
  c.report_with_single_file = true
  c.single_report_path = 'coverage/lcov.info'
end

# メタ認知: テストカバレッジは、コードの品質指標の1つです。
# 認証のような重要な機能は100%に近いカバレッジを目指すべきです。

# フォーマッタの設定（HTML形式とLCOV形式）
SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::LcovFormatter
])

# カバレッジ計測の開始
SimpleCov.start 'rails' do
  # 除外するファイル（テスト対象外のファイル）
  add_filter '/bin/'
  add_filter '/db/'
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/lib/tasks/'
  add_filter '/vendor/'
  
  # 重点的にカバレッジを取りたい認証関連のファイル
  add_group '認証サービス', ['app/services/json_web_token.rb', 'app/services/auth_service.rb']
  add_group '認証コントローラ', 'app/controllers/api/v1/auths_controller.rb'
  add_group 'ユーザー認証', 'app/models/user.rb'
  add_group 'ミドルウェア', 'app/middleware'
  
  # 通常のグループ分け
  add_group 'コントローラ', 'app/controllers'
  add_group 'モデル', 'app/models'
  add_group 'サービス', 'app/services'
  add_group 'ヘルパー', 'app/helpers'
  
  # カバレッジが低いファイルを強調表示
  minimum_coverage 80 # 全体の最低カバレッジ
  minimum_coverage_by_file 70 # 各ファイルの最低カバレッジ
  
  # 認証関連の重要なファイルは特に高いカバレッジを要求
  minimum_coverage_by_file [
    [90, ['app/services/json_web_token.rb']],
    [90, ['app/controllers/api/v1/auths_controller.rb']]
  ]
  
  # カバレッジ結果を保存するパス
  coverage_dir 'coverage'
  
  # ブランチカバレッジも計測する
  enable_coverage :branch
end

# テスト終了時に警告を表示するフックを追加
at_exit do
  # 認証関連のファイルのカバレッジをチェック
  auth_files = [
    'app/services/json_web_token.rb',
    'app/controllers/api/v1/auths_controller.rb',
    'app/models/user.rb'
  ]
  
  # 実際に計測されたカバレッジ結果を取得
  results = SimpleCov.result
  
  # 認証関連ファイルのカバレッジを検証
  auth_files.each do |file|
    if results.filenames.any? { |f| f.include?(file) }
      file_result = results.filenames.find { |f| f.include?(file) }
      coverage = results.file_report(file_result).covered_percent.round(2)
      
      # カバレッジが90%未満の場合は警告
      if coverage < 90
        puts "\n\033[33m警告: #{file} のテストカバレッジが低いです (#{coverage}%)\033[0m"
        puts "認証関連の重要ファイルなので、90%以上のカバレッジを推奨します。"
      end
    else
      puts "\n\033[31mエラー: #{file} のカバレッジが計測されていません\033[0m"
    end
  end
  
  # 全体のカバレッジを出力
  total_coverage = results.covered_percent.round(2)
  if total_coverage >= 90
    puts "\n\033[32m全体のテストカバレッジ: #{total_coverage}% (優良)\033[0m"
  elsif total_coverage >= 80
    puts "\n\033[33m全体のテストカバレッジ: #{total_coverage}% (良好)\033[0m"
  else
    puts "\n\033[31m全体のテストカバレッジ: #{total_coverage}% (改善が必要)\033[0m"
  end
end

# メタ認知: テストカバレッジだけでなく、テストの質も重要です。
# すべての条件分岐やエッジケースをテストすることを心がけましょう。 