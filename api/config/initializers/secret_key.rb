# Railsの暗号化鍵設定
# 開発/テスト環境では、16バイト（16文字）の固定キーを使用
if !Rails.env.production?
  ENV['SECRET_KEY_BASE'] = 'a1b2c3d4e5f6g7h8' # 正確に16バイト(16文字)
end 