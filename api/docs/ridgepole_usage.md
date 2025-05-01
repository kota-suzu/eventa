# Ridgepoleを使ったデータベース管理

## 概要

このプロジェクトでは、Ruby on Railsのデータベース管理にRidgepoleを使用しています。Ridgepoleは、データベーススキーマを1つの `Schemafile` で管理するツールです。従来のRailsのマイグレーションと異なり、スキーマの最終状態だけを記述するため、スキーマの管理や変更が簡単になります。

## セットアップ

1. Gemfileに `ridgepole` が追加されていることを確認
2. `bundle install` を実行してgemをインストール

## 基本的な使い方

### 現在のDBとの差分を確認

```
bundle exec rake ridgepole:diff
```

### スキーマを適用（マイグレーション実行）

```
bundle exec rake ridgepole:apply
```

### 現在のDBスキーマをエクスポート

```
bundle exec rake ridgepole:export
```

### 新しいマイグレーションファイルを作成

```
bundle exec rake ridgepole:new_migration[create_new_table]
```

## 開発フロー

1. `ridgepole:new_migration` タスクを使用して新しいマイグレーションファイルを作成
2. マイグレーションファイルを参照しながら、`db/Schemafile` を編集
3. `ridgepole:diff` で変更内容を確認
4. `ridgepole:apply` で変更を適用

## Schemafileの書き方

Schemafileでは、テーブルの最終的な状態を定義します。例：

```ruby
create_table "users", force: :cascade do |t|
  t.string   "email",           null: false
  t.string   "password_digest", null: false
  t.string   "name",            null: false
  t.timestamps
  
  t.index ["email"], name: "index_users_on_email", unique: true
end
```

### カラム追加

```ruby
add_column "users", "new_column", :string, null: false, after: "email"
```

### インデックス追加

```ruby
add_index "users", ["new_column"], name: "index_users_on_new_column"
```

### 外部キー制約

```ruby
add_foreign_key "comments", "posts"
```

## 注意事項

- Ridgepoleを使う場合、通常のRailsのマイグレーション（`rails g migration`）は使用しません
- 本番環境での変更は必ず事前にステージング環境でテストしてください
- スキーマ変更時は、既存データへの影響を考慮してください

## 参考リンク

- [Ridgepole GitHub](https://github.com/ridgepole/ridgepole)
- [Ridgepoleを使ったマイグレーション管理](https://qiita.com/kasei-san/items/cb7000d7c99481a385c7) 