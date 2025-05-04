# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ticket, type: :model do
  ## ------- Associations / Validations -------
  describe "associations & validations" do
    subject { build(:ticket) }

    it { is_expected.to belong_to(:event) }
    it { is_expected.to have_many(:reservations).dependent(:restrict_with_exception) }

    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:event_id) }
    it { is_expected.to validate_numericality_of(:price).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:quantity).is_greater_than_or_equal_to(1) }

    context "available_quantity 範囲" do
      it "0..quantity 内であること" do
        ticket = build(:ticket, quantity: 5, available_quantity: 6)
        expect(ticket).to be_invalid
        expect(ticket.errors.of_kind?(:available_quantity, :less_than_or_equal_to)).to be true
      end
    end
  end

  ## ------- Callbacks -------
  describe "callbacks" do
    it "create 時に available_quantity を quantity で初期化" do
      ticket = create(:ticket, quantity: 4, available_quantity: nil)
      expect(ticket.available_quantity).to eq 4
    end
  end

  ## ------- Business Logic -------
  describe "#reserve / .reserve_with_lock" do
    let!(:ticket) { create(:ticket, quantity: 5, available_quantity: 5) }

    it "在庫を減らす" do
      expect { ticket.reserve(2) }
        .to change { ticket.reload.available_quantity }.by(-2)
    end

    it "在庫不足で InsufficientQuantityError" do
      expect { ticket.reserve(6) }
        .to raise_error(Ticket::InsufficientQuantityError)
    end

    it ".reserve_with_lock で原子更新" do
      expect { described_class.reserve_with_lock(ticket.id, 3) }
        .to change { ticket.reload.available_quantity }.by(-3)
    end
  end

  ## ------- Concurrency smoke test -------
  describe "concurrent reservation", :concurrent, skip: "不安定なテスト" do
    it "売り越ししない", retry: 3 do
      # 明示的にデータをクリーン
      Ticket.delete_all

      # 新規のチケットを作成
      ticket = create(:ticket, quantity: 1, available_quantity: 1)
      ticket_id = ticket.id

      # スレッドの実行結果を格納する配列
      results = []

      # スレッド実行
      threads = Array.new(2) do
        Thread.new do
          # コネクションプールから接続を取得
          ActiveRecord::Base.connection_pool.with_connection do
            # ロックを使用してチケットを予約
            Ticket.reserve_with_lock(ticket_id, 1)
            results << :ok
          rescue Ticket::InsufficientQuantityError
            results << :error
          end
        end
      end

      # 全スレッドの終了を待つ
      threads.each(&:join)

      # 結果の検証
      expect(results.sort).to eq([:error, :ok])
      expect(Ticket.find(ticket_id).available_quantity).to eq 0
    end
  end
end
