# frozen_string_literal: true

require "rails_helper"

RSpec.describe TicketType, type: :model do
  describe "associations" do
    it { should belong_to(:event) }
    it { should have_many(:tickets).dependent(:restrict_with_exception) }
  end

  describe "validations" do
    let(:event) { create(:event) }
    subject { build(:ticket_type, event: event) }

    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(100) }
    
    it { should validate_presence_of(:price_cents) }
    it { should validate_numericality_of(:price_cents).is_greater_than_or_equal_to(0) }
    
    it { should validate_presence_of(:quantity) }
    it { should validate_numericality_of(:quantity).is_greater_than_or_equal_to(0) }
    
    it { should validate_presence_of(:sales_start_at) }
    it { should validate_presence_of(:sales_end_at) }
    
    it { should validate_presence_of(:status) }

    it "sales_end_at should be after sales_start_at" do
      ticket_type = build(:ticket_type, 
        sales_start_at: Time.current,
        sales_end_at: 1.hour.ago
      )
      expect(ticket_type).not_to be_valid
      expect(ticket_type.errors[:sales_end_at]).to include("は販売開始日時より後に設定してください")
    end
  end

  describe "defaults" do
    let(:event) { create(:event) }
    
    it "sets currency to JPY by default" do
      ticket_type = TicketType.new(event: event)
      expect(ticket_type.currency).to eq("JPY")
    end

    it "sets status to 'draft' by default" do
      ticket_type = TicketType.new(event: event)
      expect(ticket_type.status).to eq("draft")
    end
  end

  describe "price methods" do
    it "returns true for #free? when price_cents is 0" do
      ticket_type = build(:ticket_type, price_cents: 0)
      expect(ticket_type.free?).to be true
    end

    it "returns false for #free? when price_cents is greater than 0" do
      ticket_type = build(:ticket_type, price_cents: 1000)
      expect(ticket_type.free?).to be false
    end

    it "returns proper price in yen" do
      ticket_type = build(:ticket_type, price_cents: 100000)
      expect(ticket_type.price).to eq(1000)
    end
  end

  describe "status management" do
    let(:ticket_type) { create(:ticket_type) }

    it "can transition from draft to on_sale when valid" do
      ticket_type.update(status: "on_sale")
      expect(ticket_type.reload.status).to eq("on_sale")
    end

    it "can transition from on_sale to soldout when valid" do
      ticket_type.update(status: "on_sale")
      ticket_type.update(status: "soldout")
      expect(ticket_type.reload.status).to eq("soldout")
    end

    it "can transition from on_sale to closed when valid" do
      ticket_type.update(status: "on_sale")
      ticket_type.update(status: "closed")
      expect(ticket_type.reload.status).to eq("closed")
    end
  end

  describe "scopes" do
    let!(:past_ticket) do
      create(:ticket_type, 
        sales_start_at: 2.days.ago,
        sales_end_at: 1.day.ago,
        status: "on_sale"
      )
    end
    
    let!(:current_ticket) do
      create(:ticket_type, 
        sales_start_at: 1.day.ago,
        sales_end_at: 1.day.from_now,
        status: "on_sale"
      )
    end

    let!(:future_ticket) do
      create(:ticket_type, 
        sales_start_at: 1.day.from_now,
        sales_end_at: 2.days.from_now,
        status: "draft"
      )
    end

    let!(:soldout_ticket) do
      create(:ticket_type, status: "soldout")
    end

    it "returns on_sale tickets" do
      expect(TicketType.on_sale).to include(current_ticket)
      expect(TicketType.on_sale).not_to include(future_ticket)
      expect(TicketType.on_sale).not_to include(soldout_ticket)
    end

    it "returns active tickets (available for purchase)" do
      expect(TicketType.active).to include(current_ticket)
      expect(TicketType.active).not_to include(past_ticket)
      expect(TicketType.active).not_to include(future_ticket)
      expect(TicketType.active).not_to include(soldout_ticket)
    end
  end
end 