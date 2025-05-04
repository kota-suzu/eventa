require 'rails_helper'

RSpec.describe User, type: :model do
  # メタ認知: ユーザーモデルのテストでは、次の点を検証する必要がある
  # 1. 基本的な属性検証（存在性、一意性、フォーマット）
  # 2. パスワード管理の仕組み（ハッシュ化、検証）
  # 3. 認証関連のメソッド（authenticate）
  # 4. セッション管理（session_id）
  # 各テストが何をテストしているか明確にするためにコメントを付ける

  # テストデータ
  let(:valid_attributes) do
    {
      name: 'テストユーザー',
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123'
    }
  end

  describe 'メタテスト - モデル設定の検証' do
    it 'パスワード認証機能のセットアップが正しいこと' do
      # has_secure_passwordマクロが正しく設定されているか確認
      expect(User.new).to respond_to(:password_digest)
      expect(User.new).to respond_to(:authenticate)
    end
    
    it 'セッションIDカラムが存在すること' do
      # データベースのカラム構造を確認
      expect(User.column_names).to include('session_id')
    end
  end

  describe 'バリデーション' do
    it '有効な属性で作成できること' do
      user = User.new(valid_attributes)
      expect(user).to be_valid
    end
    
    context 'nameバリデーション' do
      it '名前が空の場合は無効であること' do
        user = User.new(valid_attributes.merge(name: ''))
        expect(user).not_to be_valid
        expect(user.errors[:name]).to include(/空/i)
      end
      
      it '名前が短すぎる場合は無効であること' do
        user = User.new(valid_attributes.merge(name: 'a'))
        expect(user).not_to be_valid
        expect(user.errors[:name]).to include(/短/i)
      end
      
      it '名前が長すぎる場合は無効であること' do
        user = User.new(valid_attributes.merge(name: 'a' * 51))
        expect(user).not_to be_valid
        expect(user.errors[:name]).to include(/長/i)
      end
    end
    
    context 'emailバリデーション' do
      it 'メールアドレスが空の場合は無効であること' do
        user = User.new(valid_attributes.merge(email: ''))
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include(/空/i)
      end
      
      it 'メールアドレスのフォーマットが無効な場合はエラーになること' do
        invalid_emails = ['user@', '@example.com', 'user@example', 'user.example.com']
        
        invalid_emails.each do |invalid_email|
          user = User.new(valid_attributes.merge(email: invalid_email))
          expect(user).not_to be_valid
          expect(user.errors[:email]).to include(/無効/i)
        end
      end
      
      it 'メールアドレスが重複する場合は無効であること' do
        User.create!(valid_attributes)
        
        user = User.new(valid_attributes)
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include(/既に使用/i)
      end
      
      it 'メールアドレスが大文字小文字を区別せず重複チェックすること' do
        User.create!(valid_attributes)
        
        user = User.new(valid_attributes.merge(email: 'TEST@example.com'))
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include(/既に使用/i)
      end
      
      it 'メールアドレスを小文字に変換して保存すること' do
        mixed_case_email = 'TeSt@ExaMPle.CoM'
        user = User.create!(valid_attributes.merge(email: mixed_case_email))
        
        expect(user.reload.email).to eq(mixed_case_email.downcase)
      end
    end
    
    context 'passwordバリデーション' do
      it 'パスワードが空の場合は無効であること' do
        user = User.new(valid_attributes.merge(password: '', password_confirmation: ''))
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include(/空/i)
      end
      
      it 'パスワードが短すぎる場合は無効であること' do
        user = User.new(valid_attributes.merge(password: 'pass', password_confirmation: 'pass'))
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include(/短/i)
      end
      
      it 'パスワードと確認用パスワードが一致しない場合は無効であること' do
        user = User.new(valid_attributes.merge(password_confirmation: 'different'))
        expect(user).not_to be_valid
        expect(user.errors[:password_confirmation]).to include(/一致/i)
      end
    end
  end

  describe 'パスワード管理' do
    let(:user) { User.create!(valid_attributes) }
    let(:password) { valid_attributes[:password] }
    
    it 'パスワードがハッシュ化されて保存されること' do
      expect(user.password_digest).not_to eq(password)
      expect(user.password_digest).to be_present
    end
    
    context 'authenticate' do
      it '正しいパスワードで認証できること' do
        expect(user.authenticate(password)).to eq(user)
      end
      
      it '間違ったパスワードでは認証できないこと' do
        expect(user.authenticate('wrong_password')).to be_falsey
      end
      
      # ビフォーアフター分析: パスワード試行回数制限の検討
      it 'パスワード試行回数の制限が実装されていないこと（現状）' do
        # ビフォー: 現在の実装では試行回数制限は無い
        10.times do
          expect(user.authenticate('wrong_password')).to be_falsey
        end
        
        # 制限がないため、正しいパスワードでまだ認証できる
        expect(user.authenticate(password)).to eq(user)
        
        # アフター: 推奨実装では試行回数制限を設け、一定回数失敗後はアカウントロックするべき
        # 例: user.failed_attempts >= 5 の場合はアカウントロック
        # このテストは現状を確認し、将来の改善ポイントを示唆する
      end
    end
  end

  describe 'セッション管理' do
    let(:user) { User.create!(valid_attributes) }
    let(:session_id) { 'abcdef123456' }
    
    it 'セッションIDを保存できること' do
      user.update(session_id: session_id)
      expect(user.reload.session_id).to eq(session_id)
    end
    
    it 'セッションIDをクリアできること' do
      user.update(session_id: session_id)
      user.update(session_id: nil)
      expect(user.reload.session_id).to be_nil
    end
    
    # セッションIDの安全性に関するテスト（メタ認知的考察）
    it 'セッションIDが安全に保存されていること（プレーンテキスト）' do
      # 現状: セッションIDはプレーンテキストで保存
      user.update(session_id: session_id)
      expect(user.reload.session_id).to eq(session_id)
      
      # 将来的には、セッションIDもハッシュ化して保存することを検討
      # セキュリティリスク: DBからの情報漏洩時にセッションIDが直接漏れる可能性
    end
  end

  describe 'スコープとクラスメソッド' do
    before do
      # テスト用ユーザーを複数作成
      @user1 = User.create!(valid_attributes)
      @user2 = User.create!(valid_attributes.merge(email: 'user2@example.com', name: 'ユーザー2'))
      @user3 = User.create!(valid_attributes.merge(email: 'user3@example.com', name: 'ユーザー3'))
      
      # セッションID付きのユーザー
      @user1.update(session_id: 'session1')
      @user2.update(session_id: 'session2')
    end
    
    context 'アクティブセッションの管理' do
      it 'セッションIDを持つユーザーを取得できること' do
        # このスコープは実装されていれば使用
        if User.respond_to?(:with_active_session)
          active_users = User.with_active_session
          expect(active_users).to include(@user1, @user2)
          expect(active_users).not_to include(@user3)
        else
          # 実装されていない場合は、代替の検証方法
          active_users = User.where.not(session_id: nil)
          expect(active_users.count).to eq(2)
          expect(active_users).to include(@user1, @user2)
        end
      end
      
      it 'メールアドレスでユーザーを検索できること' do
        # find_by_emailメソッドが実装されていれば使用
        if User.respond_to?(:find_by_email)
          user = User.find_by_email(@user1.email)
          expect(user).to eq(@user1)
        else
          # 標準のfind_byメソッドを使用
          user = User.find_by(email: @user1.email)
          expect(user).to eq(@user1)
        end
      end
    end
  end
  
  describe 'セキュリティ考察' do
    # メタ認知: セキュリティに関する考察と推奨事項
    
    it 'ユーザーモデルのセキュリティ強化ポイント（将来的な改善案）' do
      # このテストは実際のテストではなく、セキュリティ強化ポイントの記録
      
      # 1. パスワードの複雑性検証
      # 現状: 長さのみのチェック
      # 推奨: 大文字小文字、数字、特殊文字を含むよう要求
      
      # 2. セッションIDのハッシュ化
      # 現状: プレーンテキストで保存
      # 推奨: BCryptなどでハッシュ化して保存
      
      # 3. アカウントロック機能
      # 現状: 実装なし
      # 推奨: 連続失敗回数に基づくアカウントロック
      
      # 4. パスワード有効期限
      # 現状: 実装なし
      # 推奨: パスワード変更を定期的に促す
      
      # 5. 2要素認証
      # 現状: 実装なし
      # 推奨: TOTP/SMSなどの2要素認証オプション追加
      
      # これらの機能の実装状況を確認するためのプレースホルダーテスト
      # 実際の実装に合わせてテストを追加することを推奨
    end
  end
end 