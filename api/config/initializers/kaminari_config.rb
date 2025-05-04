# frozen_string_literal: true

# Kaminariのページネーション設定
Kaminari.configure do |config|
  # デフォルトの1ページあたりの表示件数を50件に設定（DoS対策）
  config.default_per_page = 50

  # 最大ページ数を設定（過剰なページング防止）
  config.max_per_page = 100

  # 左右のウィンドウサイズ
  config.window = 2

  # 外側ウィンドウサイズ
  config.outer_window = 0

  # パラメータ名の設定
  # config.param_name = :page
end
