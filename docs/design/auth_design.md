# eventa 認証・認可 Design Doc (v0.1)

**ステータス**: Draft 0.1  
**作成日**: 2025-04-30  
**作成者**: Security WG  
**レビュー担当**: Tech Lead / SRE / Product Manager / Legal

## 目的 (Why)
イベント管理プラットフォーム eventa のセキュアかつユーザーフレンドリーな認証・認可基盤を設計し、複数ロール (admin / organizer / guest)・外部 ID プロバイダ連携 (Google Workspace, Slack, LINE)・二要素認証をサポートする。PCI DSS や GDPR を遵守しつつ、拡張性と運用負荷の最小化を目指す。

## 要件まとめ

| ID | 要件 | 優先度 | 備考 |
|----|-----|-------|------|
| AUTH-01 | Eメール+パスワードのサインアップ/サインイン | Must | Devise |
| AUTH-02 | SSO (OIDC) — Google Workspace | Must | 社内向け管理者用 |
| AUTH-03 | OAuth 2.0 — LINE Login / Slack Sign-in | Should | 参加者向け |
| AUTH-04 | ロールベース権限管理 (RBAC) | Must | admin/organizer/guest |
| AUTH-05 | JWT による API 認証 | Must | Bearer token |
| AUTH-06 | TOTP による2段階認証 (2FA) | Should | QRコード設定 |
| AUTH-07 | パスワードリセットフロー | Must | 24時間有効リンク |
| AUTH-08 | セッション管理 (timeout, revoke) | Must | 30分アイドル→自動ログアウト |

## 設計の方針

### 認証基盤
- Ruby on Rails + Devise + JWT をベースとした認証基盤
- OmniAuth による外部 ID プロバイダ連携
- パスワードポリシー: 最低8文字、英数字混在、特殊文字推奨
- Pundit によるきめ細かな認可制御

### ユーザーロールモデル
```ruby
# User model
has_many :roles
has_many :permissions, through: :roles

# Role model
AVAILABLE_ROLES = %w[admin organizer guest]
has_many :permissions
```

### API認証フロー
1. サインイン時に JWT トークンを発行 (有効期限: 24時間)
2. 各 API リクエストに `Authorization: Bearer {token}` を付与
3. トークン検証 + ロール・パーミッション検証
4. レート制限適用: IP ベース + ユーザーベース

## セキュリティ考慮事項
- すべてのパスワードは bcrypt でハッシュ化
- 個人情報（メール、名前など）の暗号化保存
- ログイン試行回数制限（5回失敗→10分ロック）
- CSRF対策: セキュリティトークンの検証
- IP制限: 管理画面は特定IP範囲からのみアクセス可能

## 実装計画
1. 基本的な Email + Password 認証 (Devise)
2. ロールベース認可機能 (Pundit)
3. JWT による API 認証レイヤー
4. 外部 ID プロバイダ連携
5. 2FA 実装とセキュリティ強化

## 運用・監視
- 認証イベントの監査ログ記録 (CloudWatch Logs)
- 不審ログイン検知 (異常な地域・デバイスからのアクセス)
- 定期的なセキュリティレビュー

## 検討中の課題
- リフレッシュトークンの導入検討
- 段階的アクセス制御 (出席者→スピーカー→スタッフへの昇格フロー) 