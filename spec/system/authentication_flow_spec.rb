require 'rails_helper'

RSpec.describe "認証フロー", type: :system do
  # Capybaraのドライバー設定（JavaScriptが必要な場合）
  # driven_by :selenium_chrome_headless
  driven_by :rack_test
  
  # テスト開始時の共通処理
  before do
    # JSドライバーでテストする場合、サーバーが別プロセスで動くのでデータベースクリーニング戦略の変更が必要
    driven_by :selenium_chrome_headless if example.metadata[:js]
  end
  
  # テスト用のデータ
  let(:user_email) { "test_e2e@example.com" }
  let(:user_password) { "password123" }
  let(:user_name) { "E2Eテストユーザー" }
  
  # メタ認知：エンドツーエンドテストは、実際のユーザー体験をシミュレートするため重要です。
  # フロントエンドとバックエンドの連携に問題がないか確認できます。

  describe "新規ユーザー登録〜ログアウトまでの一連のフロー", js: true do
    it "ユーザー登録、ログイン、保護されたリソースアクセス、ログアウトができること" do
      # ステップ1: まずユーザー登録画面に訪問
      visit new_user_registration_path
      
      # ステップ2: ユーザー登録情報を入力して送信
      fill_in "user[name]", with: user_name
      fill_in "user[email]", with: user_email
      fill_in "user[password]", with: user_password
      fill_in "user[password_confirmation]", with: user_password
      click_button "アカウント登録"
      
      # 登録後にダッシュボードにリダイレクトされることを確認
      expect(page).to have_current_path(dashboard_path)
      expect(page).to have_content("アカウント登録が完了しました")
      expect(page).to have_content(user_name) # ユーザー名が表示されていることを確認
      
      # ステップ3: ログアウト
      click_link "ログアウト"
      expect(page).to have_content("ログアウトしました")
      expect(page).to have_current_path(root_path)
      
      # ステップ4: 再度ログイン
      visit new_user_session_path
      fill_in "auth[email]", with: user_email
      fill_in "auth[password]", with: user_password
      click_button "ログイン"
      
      # ログイン後にダッシュボードにリダイレクトされることを確認
      expect(page).to have_current_path(dashboard_path)
      expect(page).to have_content("ログインしました")
      
      # ステップ5: 保護されたリソースへのアクセス
      visit user_reservations_path
      expect(page).to have_current_path(user_reservations_path)
      expect(page).to have_content("予約一覧")
      
      # ステップ6: 再度ログアウト
      click_link "ログアウト"
      expect(page).to have_content("ログアウトしました")
      
      # ステップ7: ログアウト後に保護されたリソースへのアクセスができないことを確認
      visit user_reservations_path
      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_content("ログインが必要です")
    end
  end
  
  describe "トークン更新のシミュレーション", js: true do
    let!(:user) { User.create!(name: user_name, email: user_email, password: user_password) }
    
    # このテストでは、トークンの期限切れをシミュレートし、バックグラウンドでのトークン更新を検証
    it "アクセストークン期限切れ時に自動的にリフレッシュトークンでトークンが更新されること" do
      # ログイン
      visit new_user_session_path
      fill_in "auth[email]", with: user_email
      fill_in "auth[password]", with: user_password
      click_button "ログイン"
      
      expect(page).to have_current_path(dashboard_path)
      
      # JavaScriptでトークンを期限切れに設定（実際のブラウザストレージの操作）
      # 注：実際のアプリケーションの実装により調整が必要
      page.execute_script("localStorage.setItem('token_expiry', (new Date(Date.now() - 3600000)).toISOString())")
      
      # 保護されたリソースにアクセス（トークンの自動更新が発生するはず）
      visit user_reservations_path
      
      # トークン更新後もページにアクセス可能であることを確認
      expect(page).to have_current_path(user_reservations_path)
      expect(page).to have_content("予約一覧")
      
      # JavaScript経由でトークンが更新されたことを確認
      token_expiry = page.evaluate_script("localStorage.getItem('token_expiry')")
      expect(Time.parse(token_expiry) > Time.now).to be_truthy
    end
  end
  
  describe "エッジケースのテスト" do
    let!(:user) { User.create!(name: user_name, email: user_email, password: user_password) }
    
    it "無効な認証情報でログインできないこと", js: true do
      visit new_user_session_path
      fill_in "auth[email]", with: user_email
      fill_in "auth[password]", with: "wrong_password"
      click_button "ログイン"
      
      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_content("メールアドレスまたはパスワードが無効です")
    end
    
    it "セッションタイムアウト後に再ログインが必要なこと", js: true do
      # ログイン
      visit new_user_session_path
      fill_in "auth[email]", with: user_email
      fill_in "auth[password]", with: user_password
      click_button "ログイン"
      
      # セッションとトークンを無効にする（ブラウザのローカルストレージをクリア）
      page.execute_script("localStorage.clear()")
      
      # アクセスを試みる
      visit user_reservations_path
      
      # ログイン画面にリダイレクトされることを確認
      expect(page).to have_current_path(new_user_session_path)
    end
    
    it "同時に複数のブラウザでログインできること", js: true do
      # 注：このテストは概念的なものであり、実際には複数のブラウザセッションをシミュレートするため
      # 別のテスト方法が必要になる場合があります
      
      # 1つ目のセッションでログイン
      visit new_user_session_path
      fill_in "auth[email]", with: user_email
      fill_in "auth[password]", with: user_password
      click_button "ログイン"
      
      # 現在のセッションIDを保存
      first_session_id = page.evaluate_script("localStorage.getItem('session_id')")
      
      # 新しいウィンドウ/セッションの開始をシミュレート
      Capybara.using_session("second_browser") do
        # 2つ目のセッションでログイン
        visit new_user_session_path
        fill_in "auth[email]", with: user_email
        fill_in "auth[password]", with: user_password
        click_button "ログイン"
        
        # セッションが有効であることを確認
        expect(page).to have_current_path(dashboard_path)
        
        # 2つ目のセッションIDを取得
        second_session_id = page.evaluate_script("localStorage.getItem('session_id')")
        
        # 2つのセッションIDが異なることを確認
        expect(second_session_id).not_to eq(first_session_id)
      end
      
      # 元のセッションもまだ有効であることを確認
      visit user_reservations_path
      expect(page).to have_current_path(user_reservations_path)
    end
  end
  
  # メタ認知：このエンドツーエンドテストで、ユーザーの実際の操作フローに沿ったテストができました。
  # このテストは、UIとバックエンド認証の連携が正しく動作することを検証します。
  # 実際のアプリケーションの実装に合わせて、フォーム要素のIDやパスを適宜調整する必要があります。
end 