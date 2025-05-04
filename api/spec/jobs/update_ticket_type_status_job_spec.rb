# frozen_string_literal: true

require "rails_helper"

RSpec.describe UpdateTicketTypeStatusJob, type: :job do
  # テストの高速化のためモックを使用
  let(:service) { instance_double("TicketTypeStatusUpdateService") }

  before do
    # 実際のデータベースにアクセスせず、モックを使用
    allow(TicketTypeStatusUpdateService).to receive(:new).and_return(service)
    allow(service).to receive(:update_status_based_on_time)
    allow(service).to receive(:update_status_based_on_stock)
  end

  describe "#perform" do
    it "calls the status update service" do
      # サービスメソッドが呼ばれることを検証
      expect(service).to receive(:update_status_based_on_time)
      expect(service).to receive(:update_status_based_on_stock)

      # ジョブを実行
      described_class.new.perform
    end
  end
end
