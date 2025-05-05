# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::EventTickets", type: :request do
  let(:user) { create(:user) }
  let(:event) { create(:event, user: user) }
  let(:headers) { {"X-Test-User-Id" => user.id.to_s} }

  describe "GET /api/v1/events/:event_id/tickets" do
    context "when event has available tickets" do
      before do
        # 在庫があるチケット2件を作成（quantity値とavailable_quantityが一致するように設定）
        create(:ticket, event: event, title: "一般チケット", quantity: 10, available_quantity: 10)
        create(:ticket, event: event, title: "VIPチケット", quantity: 5, available_quantity: 5)

        # 在庫切れのチケット1件を作成
        create(:ticket, event: event, title: "売切れチケット", quantity: 5, available_quantity: 0)
      end

      it "returns only available tickets" do
        get "/api/v1/events/#{event.id}/tickets", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        # 返されるのは在庫のある2件のみ
        expect(json["data"].length).to eq(2)

        # タイトルが正しいことを確認
        titles = json["data"].map { |d| d["attributes"]["title"] }
        expect(titles).to include("一般チケット", "VIPチケット")
        expect(titles).not_to include("売切れチケット")
      end
    end

    context "when event has no tickets" do
      it "returns an empty array" do
        get "/api/v1/events/#{event.id}/tickets", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"].length).to eq(0)
      end
    end

    context "when event does not exist" do
      it "returns 404 not found" do
        get "/api/v1/events/9999/tickets", headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
