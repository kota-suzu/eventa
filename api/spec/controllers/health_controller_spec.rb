# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthController, type: :controller do
  # authenticate_requestをスキップするためのセットアップ
  before(:each) do
    # ApplicationControllerの認証をバイパス
    allow_any_instance_of(ApplicationController).to receive(:authenticate_request).and_return(true)
  end

  describe "GET #index" do
    # すべてのテストで共通のENVのスタブを適用
    before(:each) do
      # すべてのENVキーに対するデフォルト値を設定
      allow(ENV).to receive(:[]).and_return(nil)
      allow(ENV).to receive(:[]).with("GIT_SHA").and_return("abc123")
      allow(ENV).to receive(:[]).with("APP_VERSION").and_return("1.0.0")
      allow(ENV).to receive(:[]).with("DATABASE_CLEANER_ALLOW_REMOTE_DATABASE_URL").and_return(nil)
      allow(ENV).to receive(:[]).with("RAILS_SKIP_ROUTES").and_return(nil)
    end

    context "when all services are up" do
      before do
        # データベース接続のモック
        allow(ActiveRecord::Base.connection).to receive(:execute).with("SELECT 1")
          .and_return([{"1" => 1}])
        allow(ActiveRecord::Base.connection).to receive(:execute).with("SELECT VERSION() as version")
          .and_return([{"version" => "8.0.33"}])
      end

      it "returns status ok with 200 response" do
        get :index
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["status"]).to eq("ok")
        expect(json["database"]).to eq("connected")
        expect(json["mysql_version"]).to eq("8.0.33")
      end
    end

    context "when database connection fails" do
      before do
        # データベース接続エラーのモック
        allow(ActiveRecord::Base.connection).to receive(:execute)
          .and_raise(ActiveRecord::ConnectionNotEstablished.new("Connection not established"))
      end

      it "returns status error with 503 response" do
        get :index
        expect(response).to have_http_status(:service_unavailable)

        json = JSON.parse(response.body)
        expect(json["status"]).to eq("error")
        expect(json["database"]).to eq("error")
        expect(json["database_error"]).to be_present
      end
    end

    context "when memory usage collection succeeds" do
      before do
        # データベース接続のモック
        allow(ActiveRecord::Base.connection).to receive(:execute).with("SELECT 1")
          .and_return([{"1" => 1}])
        allow(ActiveRecord::Base.connection).to receive(:execute).with("SELECT VERSION() as version")
          .and_return([{"version" => "8.0.33"}])

        # メモリ使用量のモック
        allow(Process).to receive(:pid).and_return(12345)
        allow_any_instance_of(HealthController).to receive(:`).with("ps -o rss= -p 12345").and_return("102400")
      end

      it "includes memory usage in the response" do
        get :index
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["memory_usage_mb"]).to eq(100) # 102400 / 1024 = 100
      end
    end

    context "when memory usage collection fails" do
      before do
        # データベース接続のモック
        allow(ActiveRecord::Base.connection).to receive(:execute).with("SELECT 1")
          .and_return([{"1" => 1}])
        allow(ActiveRecord::Base.connection).to receive(:execute).with("SELECT VERSION() as version")
          .and_return([{"version" => "8.0.33"}])

        # メモリ使用量取得エラーのモック
        allow(Process).to receive(:pid).and_return(12345)
        allow_any_instance_of(HealthController).to receive(:`).with("ps -o rss= -p 12345").and_raise(StandardError.new("Command failed"))
      end

      it "includes error information but still returns status ok" do
        get :index
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["status"]).to eq("ok")
        expect(json["memory_usage_error"]).to be_present
      end
    end
  end
end
