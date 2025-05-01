# NOTE: これはサンプルです。本番の api/db/Schemafile とは別物です。
# 実際のデータベース設計はプロジェクトリポジトリの api/db/Schemafile を参照してください。
# このファイルは Ridgepole の基本的な使用方法を説明するためのものです。

# Schemafile
# このファイルにテーブル定義を記述します

# usersテーブルの例
create_table "users", force: :cascade do |t|
  t.string   "email",           null: false
  t.string   "password_digest", null: false
  t.string   "name",            null: false
  t.text     "bio"
  t.timestamps
  
  t.index ["email"], name: "index_users_on_email", unique: true
end

# eventsテーブルの例
create_table "events", force: :cascade do |t|
  t.string   "title",       null: false
  t.text     "description"
  t.datetime "start_date",  null: false
  t.datetime "end_date",    null: false
  t.string   "location"
  t.boolean  "is_public",   default: true
  t.references :user,       null: false, foreign_key: true
  t.timestamps
  
  t.index ["user_id", "start_date"], name: "index_events_on_user_id_and_start_date"
end

# participantsテーブルの例（イベント参加者）
create_table "participants", force: :cascade do |t|
  t.references :user,       null: false, foreign_key: true
  t.references :event,      null: false, foreign_key: true
  t.string     "status",    null: false, default: "pending" # pending, accepted, declined
  t.timestamps
  
  t.index ["user_id", "event_id"], name: "index_participants_on_user_id_and_event_id", unique: true
end

# bulk_changeブロックで複数の変更をまとめてトランザクション処理する例
bulk_change do
  add_column "users", "last_login_at", :datetime
  add_column "users", "login_count", :integer, default: 0
  add_column "users", "account_status", :string, default: "active"
end 