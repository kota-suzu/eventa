# SEGVエラーからの復旧ガイド

このガイドでは、Ruby/RailsプロジェクトでよくあるSegmentation Fault（SEGV）エラーの対処法について説明します。特にテスト実行時などに発生する「SEGV received in SEGV handler」というエラーに焦点を当てています。

## 発生状況と原因

SEGVエラーは主に以下のような状況で発生します：

1. **データベーステーブルの不足**: ActiveRecordが存在しないテーブルにアクセスしようとする場合
2. **ネイティブ拡張の問題**: mysql2やpg、nokogiriなどのネイティブ拡張gemに問題がある場合
3. **メモリ不足**: Rubyプロセスが利用可能なメモリを使い果たした場合

特にCIパイプラインでは、**データベーススキーマの準備が不十分**な場合にSEGVエラーが発生しやすいです。

### db:prepare 実行中のSEGVエラー

特に `rails db:prepare` 実行中にSEGVエラーが発生する場合、次のような原因が考えられます：

1. **seeds.rbでのテーブルアクセス**: テーブルが作成される前にseedsスクリプトがそのテーブルにアクセスしようとしている
2. **スキーマファイルの重複・競合**: 複数の異なるバージョンのスキーマファイルが存在し、一貫性のない状態になっている
3. **Ridgepoleとrails db:prepareの混在**: プロジェクトがRidgepole（外部スキーマツール）とRailsのマイグレーションを混在させている

## 診断手順

### 1. データベース状態の確認

```bash
# ローカル環境で実行
make diagnose-db
make ci-healthcheck

# または直接
bundle exec rails runner 'puts ActiveRecord::Base.connection.tables.sort'
```

### 2. ログの確認

SEGVエラーの前に出力されているログを確認し、どのような操作中にクラッシュしたかを特定します。

```
ActiveRecord::StatementInvalid - Mysql2::Error: Table 'xxx' doesn't exist
```

のようなエラーがSEGVの前にある場合は、データベーススキーマの問題が原因である可能性が高いです。

## 解決策

### データベーススキーマの問題を解決する

1. **rails db:prepareの代わりにRidgepoleを直接使用する**（このプロジェクト推奨）

```bash
# ローカル環境
bundle exec rails db:create RAILS_ENV=test
bundle exec ridgepole -c config/database.yml -E test --apply -f db/Schemafile

# CI環境
- name: データベースをセットアップ
  run: |
    # データベース作成
    bundle exec rails db:create RAILS_ENV=test
    
    # スキーマを明示的に適用
    bundle exec ridgepole -c config/database.yml -E test --apply -f db/Schemafile
    
    # テーブル確認
    bundle exec rails runner 'critical_tables = %w[events users tickets ticket_types]; 
    missing = critical_tables - ActiveRecord::Base.connection.tables; 
    if missing.empty?; puts "✅ 重要テーブルは全て存在します"; 
    else; puts "❌ 不足テーブル: #{missing.join(", ")}"; exit 1; end'
  working-directory: ./api
```

2. **seeds.rbファイルにテーブル存在確認を追加する**

```ruby
# seeds.rbの先頭に追加
required_tables = %w[users events tickets]
missing_tables = required_tables - ActiveRecord::Base.connection.tables
unless missing_tables.empty?
  puts "⚠️ 以下のテーブルが存在しないため、seedデータの作成をスキップします: #{missing_tables.join(', ')}"
  exit(0)
end

# 以下、通常のseed処理...
```

3. **rails db:prepare を使用する場合（代替手段）**

```bash
# ローカル環境
make repair-test-db  # または
bundle exec rails db:prepare RAILS_ENV=test
```

### ネイティブ拡張の問題を解決する

ネイティブ拡張が原因でSEGVが発生する場合：

1. **依存関係をリビルド**

```bash
bundle pristine mysql2  # または問題のあるgem名
bundle pristine --all   # すべてのgemをリビルド
```

2. **システムライブラリを更新**

```bash
# Ubuntuの場合
apt-get update
apt-get install -y libmysqlclient-dev  # またはlibpq-dev、libxml2-devなど
```

### メモリ不足の解決

1. **CIリソースを増やす**

```yaml
# GitHub Actionsの場合
jobs:
  test:
    runs-on: ubuntu-latest
    container:
      options: --memory 4g  # メモリ制限を増加
```

2. **テストの分割実行**

特定のテストだけを実行して問題を切り分けます。

## 予防策

1. **CI環境で毎回テーブル確認を行う**
2. **ローカル環境で `make ci-simulate` を実行してCIパイプラインをシミュレート**
3. **`rails db:prepare` を使ってデータベースを確実に準備**

## 関連資料

- [CI環境でのトラブルシューティングガイド](ci_troubleshooting.md)
- [データベースマイグレーションのベストプラクティス](database_migration_best_practices.md) 