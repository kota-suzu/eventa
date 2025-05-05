# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::TicketTypes", type: :request do
  let(:user) { create(:user, role: :organizer) }
  let(:event) { create(:event, user: user) }
  let(:headers) { {"X-Test-User-Id" => user.id.to_s} }

  before do
    allow_any_instance_of(Api::V1::TicketTypesController).to receive(:authenticate_user).and_return(true)
    allow_any_instance_of(Api::V1::TicketTypesController).to receive(:authorize_event_owner!).and_return(true)
    allow_any_instance_of(Api::V1::TicketTypesController).to receive(:current_user).and_return(user)
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
  end
end
