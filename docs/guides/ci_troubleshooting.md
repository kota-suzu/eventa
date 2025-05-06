# CI環境でのトラブルシューティングガイド

本ドキュメントでは、CI環境で発生しやすい問題とその解決策について説明します。

## データベース関連の問題

### テーブル不足エラーとSEGVクラッシュ

#### 問題

以下のようなエラーが発生する場合：

```
ActiveRecord::StatementInvalid - Mysql2::Error: Table 'eventa_test.tickets' doesn't exist
ActiveRecord::StatementInvalid - Mysql2::Error: Table 'eventa_test.users' doesn't exist
```

または、テスト実行中に以下のようなセグメンテーションフォルトが発生する場合：

```
SEGV received in SEGV handler
/path/to/gems/mysql2-x.x.x/lib/mysql2/client.rb:xx: [BUG] Segmentation fault
```

これらはテスト環境のデータベーススキーマが正しく適用されていないことを示しています。特にSEGVエラーは、テーブルがないためにActiveRecordが例外を連発し、MySQL2ドライバがクラッシュすることで発生します。

#### 原因

本プロジェクトでは通常のRailsマイグレーションではなく、Ridgepole（リッジポール）を使用してデータベーススキーマを管理しています。CIの設定でRidgepoleによるスキーマ適用ステップが不足しているか、正しく適用されていない場合にこの問題が発生します。

#### 解決策

CI環境では、テストの実行前に以下のいずれかのアプローチでデータベーススキーマを準備できます：

**アプローチ1: Rails標準の`db:prepare`を使用（推奨）**

```yaml
- name: テストデータベースを準備
  run: |
    bundle exec rails db:prepare RAILS_ENV=test
  working-directory: ./api
```

このアプローチは自動的にデータベースの作成とスキーマのロードを行います。マイグレーションが変更された場合も適切に対応します。

**アプローチ2: Ridgepoleを使用（従来の方法）**

```yaml
- name: テストデータベースを準備
  run: |
    bundle exec rails db:create RAILS_ENV=test
    bundle exec ridgepole -c config/database.yml -E test --apply -f db/Schemafile
  working-directory: ./api
```

このステップをGitHub Actionsのワークフロー設定に追加することで、テスト実行前に正しいスキーマが適用されます。

#### ローカル環境での確認方法

ローカル環境でスキーマの状態を確認するには、以下のコマンドを実行できます：

```bash
make diagnose-db
```

テスト環境のデータベースを修復する必要がある場合は：

```bash
make repair-test-db
```

### データベース環境の統一

#### 問題

CI環境内で異なるワークフロー間でデータベース環境（MySQLとPostgreSQLなど）が混在していると、テスト結果の一貫性が保てない場合があります。

#### 解決策

すべてのワークフローで同じデータベース（このプロジェクトではMySQL）を使用するように統一します：

```yaml
services:
  mysql:
    image: mysql:8.0
    env:
      MYSQL_ROOT_PASSWORD: rootpass
      MYSQL_DATABASE: eventa_test
    ports:
      - 3306:3306
    options: >-
      --health-cmd="mysqladmin ping -h localhost -prootpass"
      --health-interval=10s
      --health-timeout=5s
      --health-retries=5

env:
  RAILS_ENV: test
  DB_HOST: 127.0.0.1
  DB_PORT: 3306
  DB_USER: root
  DB_PASSWORD: rootpass
  DB_NAME: eventa_test
```

これにより、開発環境とCI環境、および各ワークフロー間での一貫性が確保されます。

### database.yml設定の問題

#### 問題

CI環境で異なるデータベース設定（例：ホスト名、ポート、認証情報）が必要な場合があります。

#### 解決策

`config/database.yml.ci`ファイルを用意し、CIワークフローで以下のようにコピーします：

```yaml
- name: Setup CI database config
  run: |
    cp config/database.yml.ci config/database.yml
  working-directory: ./api
```

## その他のCI問題

このセクションは、他のCI関連の問題が発生した場合に拡張します。
