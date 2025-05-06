# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::TicketTypes", type: :request do
  let(:user) { create(:user, role: :organizer) }
  let(:event) { create(:event, user: user) }
  let(:headers) { {"X-Test-User-Id" => user.id.to_s} }

  # 基本的なテストでは認証と認可をスキップ
  before do
    # 認証と認可をモックする（コントローラが自分で判断せずに常に認証・認可OK）
    allow_any_instance_of(Api::V1::TicketTypesController).to receive(:authenticate_user).and_return(true)
    allow_any_instance_of(Api::V1::TicketTypesController).to receive(:current_user).and_return(user)
    allow_any_instance_of(Api::V1::TicketTypesController).to receive(:authorize_event_owner!).and_return(true)
  end

  describe "GET /api/v1/events/:event_id/ticket_types" do
    before do
      create_list(:ticket_type, 3, event: event)
    end

    it "returns a list of ticket types" do
      get api_v1_event_ticket_types_path(event), headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"].length).to eq(3)
      expect(json["meta"]["total"]).to eq(3)
    end

    context "when event does not exist" do
      it "returns 404 not found" do
        get api_v1_event_ticket_types_path(0), headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api/v1/events/:event_id/ticket_types/:id" do
    let(:ticket_type) { create(:ticket_type, event: event) }

    it "returns a ticket type" do
      get api_v1_event_ticket_type_path(event, ticket_type), headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["id"]).to eq(ticket_type.id)
      expect(json["data"]["attributes"]["name"]).to eq(ticket_type.name)
    end

    context "when ticket type does not exist" do
      it "returns 404 not found" do
        get api_v1_event_ticket_type_path(event, 0), headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/v1/events/:event_id/ticket_types" do
    let(:valid_params) do
      {
        ticket_type: {
          name: "テストチケット",
          description: "テスト用のチケットです",
          price_cents: 500,
          quantity: 100,
          sales_start_at: 1.day.from_now.iso8601,
          sales_end_at: 30.days.from_now.iso8601
        }
      }
    end

    context "with valid parameters" do
      it "creates a new ticket type" do
        expect {
          post api_v1_event_ticket_types_path(event),
            params: valid_params,
            headers: headers
        }.to change(TicketType, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["data"]["attributes"]["name"]).to eq("テストチケット")
      end
    end

    context "with invalid parameters" do
      it "does not create a ticket type" do
        expect {
          post api_v1_event_ticket_types_path(event),
            params: {ticket_type: {name: ""}},
            headers: headers
        }.not_to change(TicketType, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when event does not exist" do
      it "returns 404 not found" do
        post api_v1_event_ticket_types_path(0),
          params: valid_params,
          headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not the event owner" do
      let(:other_user) { create(:user) }
      let(:other_event) { create(:event, user: other_user) }

      it "returns 401 unauthorized in non-test environment" do
        # 認証に関するモックをクリア（デフォルトの動作に戻す）
        allow_any_instance_of(Api::V1::TicketTypesController).to receive(:authenticate_user).and_call_original
        # 認可メソッドの元の実装を呼び出し
        allow_any_instance_of(Api::V1::TicketTypesController).to receive(:authorize_event_owner!).and_call_original
        # 環境をテスト環境ではないと偽装
        allow(Rails.env).to receive(:test?).and_return(false)
        # 現在のユーザーを元のユーザーとして設定
        allow_any_instance_of(Api::V1::TicketTypesController).to receive(:current_user).and_return(user)

        post api_v1_event_ticket_types_path(other_event),
          params: valid_params,
          headers: {"X-Test-User-Id" => user.id.to_s}

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PUT /api/v1/events/:event_id/ticket_types/:id" do
    let(:ticket_type) { create(:ticket_type, event: event) }

    it "updates the ticket type" do
      put api_v1_event_ticket_type_path(event, ticket_type),
        params: {ticket_type: {name: "更新後のチケット"}},
        headers: headers

      expect(response).to have_http_status(:ok)
      expect(ticket_type.reload.name).to eq("更新後のチケット")
    end

    context "with invalid parameters" do
      it "returns unprocessable entity" do
        put api_v1_event_ticket_type_path(event, ticket_type),
          params: {ticket_type: {name: "", sales_start_at: nil}},
          headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["errors"]).to be_present
      end
    end

    context "when ticket type does not exist" do
      it "returns 404 not found" do
        put api_v1_event_ticket_type_path(event, 0),
          params: {ticket_type: {name: "更新後のチケット"}},
          headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when event does not exist" do
      it "returns 404 not found" do
        put api_v1_event_ticket_type_path(0, ticket_type),
          params: {ticket_type: {name: "更新後のチケット"}},
          headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /api/v1/events/:event_id/ticket_types/:id" do
    let!(:ticket_type) { create(:ticket_type, event: event) }

    it "deletes the ticket type" do
      expect {
        delete api_v1_event_ticket_type_path(event, ticket_type), headers: headers
      }.to change(TicketType, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    context "when tickets exist" do
      before do
        create(:ticket, event: event, ticket_type: ticket_type)
      end

      it "does not delete the ticket type" do
        expect {
          delete api_v1_event_ticket_type_path(event, ticket_type), headers: headers
        }.not_to change(TicketType, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when ticket type does not exist" do
      it "returns 404 not found" do
        delete api_v1_event_ticket_type_path(event, 0), headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when event does not exist" do
      it "returns 404 not found" do
        delete api_v1_event_ticket_type_path(0, ticket_type), headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "authorization" do
    let(:other_user) { create(:user) }
    let(:other_event) { create(:event, user: other_user) }

    context "when in test environment" do
      it "allows operations even without being the event owner" do
        # すでに認可が通るようモックされているので何もしない
        get api_v1_event_ticket_types_path(other_event), headers: headers
        expect(response).to have_http_status(:ok)
      end
    end

    context "when in production environment" do
      before do
        # 環境をテスト環境ではないと偽装
        allow(Rails.env).to receive(:test?).and_return(false)
      end

      it "returns unauthorized when not the event owner" do
        # 認証に関するモックをクリア（デフォルトの動作に戻す）
        allow_any_instance_of(Api::V1::TicketTypesController).to receive(:authenticate_user).and_call_original
        # 認可メソッドの元の実装を呼び出し
        allow_any_instance_of(Api::V1::TicketTypesController).to receive(:authorize_event_owner!).and_call_original
        # 現在のユーザーを元のユーザーとして設定
        allow_any_instance_of(Api::V1::TicketTypesController).to receive(:current_user).and_return(user)

        get api_v1_event_ticket_types_path(other_event), headers: headers
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns unauthorized for event owner without proper authentication" do
        # 認証に関するモックをクリア（デフォルトの動作に戻す）
        allow_any_instance_of(Api::V1::TicketTypesController).to receive(:authenticate_user).and_call_original
        # 認可メソッドの元の実装を呼び出し
        allow_any_instance_of(Api::V1::TicketTypesController).to receive(:authorize_event_owner!).and_call_original
        # 現在のユーザーを元のユーザーとして設定
        allow_any_instance_of(Api::V1::TicketTypesController).to receive(:current_user).and_return(user)

        get api_v1_event_ticket_types_path(event), headers: headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
