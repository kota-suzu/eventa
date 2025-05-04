# Eventa ドキュメントリポジトリ

**ステータス**: Active  
**最終更新日**: 2025-05-04

## 目次

1. [ドキュメントの構成](#ドキュメントの構成)
2. [最近の更新](#最近の更新)
3. [開発者向けリソース](#開発者向けリソース)
4. [貢献ガイドライン](#貢献ガイドライン)

## ドキュメントの構成

Eventa のドキュメントは以下のディレクトリに分類されています:

- **[/guides](/guides)**: 開発・運用に関するガイドライン
  - [APIサービス開発ガイド](/guides/api_development.md)
  - [フロントエンド開発ガイド](/guides/frontend_development.md)
  - [CI/CD運用ガイド](/guides/cicd_operations.md)
  - [認証システム開発ガイド](/guides/authentication_guide.md) **NEW**
  - [フロントエンド認証統合ガイド](/guides/frontend_auth_integration.md) **NEW**

- **[/specifications](/specifications)**: API仕様やシステム要件
  - [API仕様書](/specifications/api_reference.md) **UPDATED**
  - [認証・認可の仕様](/specifications/auth_specs.md)
  - [エラーコード一覧](/specifications/error_codes.md)

- **[/design](/design)**: システム設計ドキュメント
  - [全体アーキテクチャ](/design/architecture.md)
  - [DB設計](/design/database_design.md)
  - [認証システム設計](/design/auth_design.md) **UPDATED**
  - [イベント管理設計](/design/event_management.md)

- **[/database](/database)**: データベース関連ドキュメント
  - [テーブル定義](/database/table_definitions.md)
  - [ER図](/database/er_diagram.png)
  - [マイグレーション計画](/database/migration_plan.md)

- **[/product](/product)**: 製品仕様・ロードマップ
  - [製品ロードマップ](/product/roadmap.md)
  - [リリース計画](/product/release_plan.md)
  - [変更履歴](/product/changelog.md)

## 最近の更新

### 2025-05-04: 認証システム関連ドキュメントの強化

JWT認証とリフレッシュトークンを使った認証システムのアップデートに伴い、以下のドキュメントが更新・追加されました：

1. **[認証システム設計](/design/auth_design.md)** - バージョン2.0にアップデート
   - JWTおよびリフレッシュトークンの詳細仕様
   - シーケンス図による認証フローの視覚化
   - セキュリティ強化策と代替案の分析
   - 将来の拡張性に関する計画

2. **[認証システム開発ガイド](/guides/authentication_guide.md)** - 新規追加
   - 開発環境のセットアップ方法
   - JWT実装の詳細コード例
   - リフレッシュトークン実装のガイド
   - テスト方法とデバッグのヒント
   - セキュリティのベストプラクティス

3. **[フロントエンド認証統合ガイド](/guides/frontend_auth_integration.md)** - 新規追加
   - React + TypeScriptでの認証コンテキスト実装
   - APIインターセプターの設定例
   - トークン管理のベストプラクティス
   - セキュリティ考慮事項と対策
   - テスト方法とトラブルシューティング

4. **[API仕様書](/specifications/api_reference.md)** - 更新
   - リフレッシュトークンエンドポイントの追加
   - JWT形式の詳細説明の追加
   - レスポンス例の更新
   - セキュリティ要件の更新

これらのドキュメントは、セキュアで拡張性の高い認証システムの実装と運用をサポートし、フロントエンドとバックエンドの連携を円滑にします。

### 2025-04-20: 初期ドキュメント構成の完成

- 基本的なドキュメント構造の構築
- 主要なシステム設計ドキュメントの作成
- API仕様書の初版リリース

## 開発者向けリソース

### API開発

1. **認証システム**:
   - [認証システム設計](/design/auth_design.md)
   - [認証システム開発ガイド](/guides/authentication_guide.md)
   - [API認証エンドポイント仕様](/specifications/api_reference.md#authentication)

2. **イベント管理**:
   - [イベント管理設計](/design/event_management.md)
   - [イベントAPI仕様](/specifications/api_reference.md#events)

### フロントエンド開発

1. **認証・セッション管理**:
   - [フロントエンド認証統合ガイド](/guides/frontend_auth_integration.md)
   - [状態管理パターン](/guides/frontend_development.md#state-management)

2. **UI/UXガイドライン**:
   - [デザインシステム](/guides/frontend_development.md#design-system)
   - [アクセシビリティ要件](/guides/frontend_development.md#accessibility)

## 貢献ガイドライン

1. **ドキュメントの更新方法**:
   - Pull Requestベースの更新
   - Markdownフォーマットの維持
   - 図表はPlantUML, Mermaid, またはDrawio形式を推奨

2. **レビュープロセス**:
   - 技術的レビュー：Tech Leadまたは該当モジュールの担当者
   - 内容的レビュー：Product Managerまたはチームリード

3. **バージョン管理**:
   - ドキュメントにはバージョンと最終更新日を明記
   - 変更履歴を含めること

## メンテナンス担当

- **認証システム関連**: Security Team (@security-team)
- **API開発関連**: Backend Team (@backend-team)
- **フロントエンド関連**: Frontend Team (@frontend-team)
- **DB設計関連**: Database Team (@db-team)
- **全体管理**: Documentation Team (@docs-team) 