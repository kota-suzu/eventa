# frozen_string_literal: true

require "rails_helper"

RSpec.describe UpdateTicketTypeStatusJob, type: :job do
  describe "#perform" do
    let!(:past_draft) { create(:ticket_type, status: "draft", sales_start_at: 2.days.ago, sales_end_at: 30.days.from_now) }
    let!(:future_draft) { create(:ticket_type, status: "draft", sales_start_at: 2.days.from_now, sales_end_at: 30.days.from_now) }
    let!(:expired_on_sale) { create(:ticket_type, status: "on_sale", sales_start_at: 30.days.ago, sales_end_at: 1.day.ago) }
    let!(:active_on_sale) { create(:ticket_type, status: "on_sale", sales_start_at: 30.days.ago, sales_end_at: 30.days.from_now) }
    
    # 売切れテスト用
    let!(:sold_out_ticket_type) do
      ticket_type = create(:ticket_type, status: "on_sale", quantity: 10)
      allow(ticket_type).to receive(:remaining_quantity).and_return(0)
      allow(TicketType).to receive(:find_each).and_yield(ticket_type)
      ticket_type
    end

    it "updates draft to on_sale when sales_start_at is passed" do
      described_class.new.perform
      expect(past_draft.reload.status).to eq("on_sale")
      expect(future_draft.reload.status).to eq("draft")
    end

    it "updates on_sale to closed when sales_end_at is passed" do
      described_class.new.perform
      expect(expired_on_sale.reload.status).to eq("closed")
      expect(active_on_sale.reload.status).to eq("on_sale")
    end

    it "updates on_sale to soldout when remaining_quantity is 0" do
      # テスト前の準備
      original_find_each = TicketType.method(:find_each)
      allow(TicketType).to receive(:find_each) do |&block|
        block.call(sold_out_ticket_type)
      end

      described_class.new.perform
      expect(sold_out_ticket_type.reload.status).to eq("soldout")
      
      # restore original method
      allow(TicketType).to receive(:find_each).and_call_original
    end
  end
end 