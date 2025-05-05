# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthController, type: :controller do
  describe "GET #check" do
    # すべてのテストで共通のENVのスタブを適用
    before(:each) do
      # すべてのENVキーに対するデフォルト値を設定
      allow(ENV).to receive(:[]).and_return(nil)
      allow(ENV).to receive(:[]).with("REDIS_URL").and_return("redis://localhost:6379")
      allow(ENV).to receive(:[]).with("GIT_SHA").and_return("abc123")
      allow(ENV).to receive(:[]).with("APP_VERSION").and_return("1.0.0")
      allow(ENV).to receive(:[]).with("DATABASE_CLEANER_ALLOW_REMOTE_DATABASE_URL").and_return(nil)
      allow(ENV).to receive(:[]).with("RAILS_SKIP_ROUTES").and_return(nil)
    end

    context "when all services are up" do
      before do
        # データベース接続のモック
        allow_any_instance_of(ActiveRecord::ConnectionAdapters::ConnectionPool).to receive(:with_connection)
          .and_yield(double(select_value: 1))

        # Redis接続のモック
        allow(Redis).to receive(:new).and_return(double(ping: "PONG"))
      end

      it "returns status ok with 200 response" do
        get :check
        expect(response).to have_http_status(:ok)
        
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("ok")
        expect(json["database"]).to eq("connected")
        expect(json["redis"]).to eq("connected")
      end
    end

    context "when database connection fails" do
      before do
        # データベース接続エラーのモック
        allow_any_instance_of(ActiveRecord::ConnectionAdapters::ConnectionPool).to receive(:with_connection)
          .and_raise(ActiveRecord::ConnectionNotEstablished.new("Connection not established"))
        
        # Redis接続は正常
        allow(Redis).to receive(:new).and_return(double(ping: "PONG"))
      end

      it "returns status error with 503 response" do
        get :check
        expect(response).to have_http_status(:service_unavailable)
        
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("error")
        expect(json["database"]).to eq("error")
        expect(json["database_message"]).to be_present
      end
    end

    context "when database connection times out" do
      before do
        # タイムアウトエラーのモック
        allow_any_instance_of(ActiveRecord::ConnectionAdapters::ConnectionPool).to receive(:with_connection)
          .and_raise(Timeout::Error.new("Database connection timeout"))
        
        # Redis接続は正常
        allow(Redis).to receive(:new).and_return(double(ping: "PONG"))
      end

      it "returns status error with 503 response" do
        get :check
        expect(response).to have_http_status(:service_unavailable)
        
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("error")
        expect(json["database"]).to eq("timeout")
      end
    end

    context "when Redis connection fails" do
      before do
        # データベース接続は正常
        allow_any_instance_of(ActiveRecord::ConnectionAdapters::ConnectionPool).to receive(:with_connection)
          .and_yield(double(select_value: 1))
        
        # Redis接続エラーのモック
        allow(Redis).to receive(:new).and_raise(Redis::CannotConnectError.new("Redis connection error"))
      end

      it "returns status warning with 200 response" do
        get :check
        expect(response).to have_http_status(:ok)
        
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("warning")
        expect(json["database"]).to eq("connected")
        expect(json["redis"]).to eq("error")
        expect(json["redis_message"]).to be_present
      end
    end

    context "when Redis is not configured" do
      before do
        # データベース接続は正常
        allow_any_instance_of(ActiveRecord::ConnectionAdapters::ConnectionPool).to receive(:with_connection)
          .and_yield(double(select_value: 1))
        
        # Redisが設定されていない状態をモック
        allow(ENV).to receive(:[]).with("REDIS_URL").and_return(nil)
      end

      it "returns status ok with redis not_configured" do
        get :check
        expect(response).to have_http_status(:ok)
        
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("ok")
        expect(json["database"]).to eq("connected")
        expect(json["redis"]).to eq("not_configured")
      end
    end
  end
end
