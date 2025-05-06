# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# テーブルの存在確認
puts "テーブル存在確認を行います..."
required_tables = %w[users events tickets]
missing_tables = required_tables - ActiveRecord::Base.connection.tables
unless missing_tables.empty?
  puts "⚠️ 以下のテーブルが存在しないため、seedデータの作成をスキップします: #{missing_tables.join(", ")}"
  puts "ℹ️ スキーマが適用されているか確認してください。"
  exit(0) # エラーではなく正常終了
end

puts "✅ 必要なテーブルが全て存在します。seedデータの作成を開始します..."

# 管理者ユーザーの作成
admin = User.create_with(
  name: "管理者",
  password: "password",
  role: "admin"
).find_or_create_by!(email: "admin@example.com")

# テストユーザーの作成
User.create_with(
  name: "テストユーザー",
  password: "password"
).find_or_create_by!(email: "user@example.com")

# イベント作成
event1 = Event.create_with(
  description: "一日限りの特別イベント！多くの出演者と楽しいプログラムを用意してお待ちしております。",
  start_at: 1.month.from_now,
  end_at: 1.month.from_now + 3.hours,
  venue: "東京国際フォーラム",
  capacity: 1000,
  is_public: true
).find_or_create_by!(title: "ウィンターフェスティバル", user: admin)

event2 = Event.create_with(
  description: "春の訪れを祝うコンサート。多くのアーティストが出演します。",
  start_at: 2.months.from_now,
  end_at: 2.months.from_now + 4.hours,
  venue: "大阪城ホール",
  capacity: 1500,
  is_public: true
).find_or_create_by!(title: "スプリングコンサート", user: admin)

# チケット作成
Ticket.create_with(
  description: "一般入場チケット",
  price: 5000,
  quantity: 800,
  available_quantity: 800
).find_or_create_by!(title: "一般席", event: event1)

Ticket.create_with(
  description: "VIPエリアへのアクセス、特典付き",
  price: 12000,
  quantity: 200,
  available_quantity: 200
).find_or_create_by!(title: "VIP席", event: event1)

Ticket.create_with(
  description: "一般入場チケット",
  price: 4500,
  quantity: 1000,
  available_quantity: 1000
).find_or_create_by!(title: "一般席", event: event2)

Ticket.create_with(
  description: "VIPエリアへのアクセス、特典付き",
  price: 10000,
  quantity: 500,
  available_quantity: 500
).find_or_create_by!(title: "VIP席", event: event2)

puts "Seed data created successfully!"
