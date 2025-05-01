# Ridgepoleを使ったデータベース管理ガイド

## 概要

Ridgepoleは、DBマイグレーションの代わりにSchemafileを使用してスキーマを宣言的に管理するためのツールです。Railsの標準的なマイグレーション機能とは異なり、スキーマの最終状態をファイルで定義し、データベースをその状態に同期させる仕組みです。

## メリット

- スキーマの全体像を1つのファイル（`db/Schemafile`）で確認できる
- テーブル間の依存関係を意識せずにスキーマを定義できる
- スキーマの差分を自動検出し、必要な変更のみ適用する

## 利用方法

### 基本コマンド

Makefileに定義されたコマンドを使って操作します：

```bash
# スキーマ変更のシミュレーション実行
make db-dry-run

# スキーマ変更の適用
make db-apply

# 現在のDBスキーマをSchemafileに出力
make db-export
```

### 一般的なワークフロー

1. 現在のスキーマをエクスポート: `make db-export`
2. `db/Schemafile`を編集して必要な変更を加える
3. 変更内容をシミュレーション: `make db-dry-run`
4. 問題なければ変更を適用: `make db-apply`

### 注意点

- **空のSchemafileに注意!** 空のSchemafileを適用すると全テーブルが削除される危険があります
- 最初に必ず`make db-export`でスキーマを出力してから編集を始めてください
- 本番環境への適用前は必ず`--dry-run`オプションでシミュレーションを実行してください

## Schemafileの書き方

### テーブル定義

```ruby
create_table "users", force: :cascade do |t|
  t.string   "name", null: false
  t.string   "email", null: false, index: { unique: true }
  t.timestamps
end
```

### 外部キー

```ruby
create_table "posts" do |t|
  t.references :user, null: false, foreign_key: true
  # または
  t.bigint "user_id", null: false
  # ...
end

# テーブル定義の外に書く場合
add_foreign_key "posts", "users"
```

### インデックス

```ruby
create_table "users" do |t|
  # ...
  t.index ["email"], name: "index_users_on_email", unique: true
  # または
  t.string "email", index: { unique: true }
end
```

### bulk_changeブロック

複数の変更をトランザクションで実行する場合に便利です：

```ruby
bulk_change do
  add_column "users", "login_count", :integer, default: 0
  add_column "users", "last_login_at", :datetime
  add_index "users", ["last_login_at"]
end
```

## 参考リンク

- [公式GitHub](https://github.com/ridgepole/ridgepole) - 最新の情報やオプションなど
- [Qiita記事](https://qiita.com/Kta-M/items/c47889de8291a62a8a85) - 基本的な使い方 