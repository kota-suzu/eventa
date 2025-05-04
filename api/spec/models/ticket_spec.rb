# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ticket, type: :model do
  describe "バリデーション" do
    it "有効なチケットは作成できる" do
      ticket = build(:ticket)
      expect(ticket).to be_valid
    end

    it "タイトルなしでは無効" do
      ticket = build(:ticket, title: nil)
      expect(ticket).not_to be_valid
      expect(ticket.errors[:title]).to include("を入力してください")
    end

    it "イベントIDなしでは無効" do
      ticket = build(:ticket, event_id: nil)
      expect(ticket).not_to be_valid
      expect(ticket.errors[:event_id]).to include("を入力してください")
    end

    it "価格は0以上でなければならない" do
      ticket = build(:ticket, price: -100)
      expect(ticket).not_to be_valid
      expect(ticket.errors[:price]).to include("は0以上の値にしてください")
    end

    it "在庫数は1以上でなければならない" do
      ticket = build(:ticket, quantity: 0)
      expect(ticket).not_to be_valid
      expect(ticket.errors[:quantity]).to include("は1以上の値にしてください")
    end
  end

  describe "在庫管理" do
    let(:ticket) { create(:ticket, quantity: 5, available_quantity: 5) }

    it "予約で在庫を減らせる" do
      expect {
        ticket.reserve(2)
      }.to change { ticket.reload.available_quantity }.by(-2)
    end

    it "在庫以上の予約はエラーとなる" do
      expect {
        ticket.reserve(6)
      }.to raise_error(Ticket::InsufficientQuantityError)
    end

    it "同時予約で競合が発生しないこと" do
      # 悲観的ロックのテスト
      threads = []
      3.times do
        threads << Thread.new do
          Ticket.transaction do
            t = Ticket.lock.find(ticket.id)
            t.reserve(1)
          end
        end
      end
      threads.each(&:join)

      # 全スレッド完了後に在庫を確認
      expect(ticket.reload.available_quantity).to eq(2)
    end
  end
end
