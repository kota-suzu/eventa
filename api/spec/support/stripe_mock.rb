# frozen_string_literal: true

# Stripeモジュールとクラスのモック
module Stripe
  class Charge
    attr_reader :id, :status

    def initialize(id:, status:)
      @id = id
      @status = status
    end

    def self.create(params)
      # テスト用の成功レスポンスを返す
      new(id: "ch_#{SecureRandom.hex(8)}", status: "succeeded")
    end
  end

  # CardErrorクラスはすでに実際のStripe gemで定義されているため、
  # モックではなく実際のクラスを使用します。
  # 必要に応じてここでは代わりにモックメソッドを定義します。
  # 例：
  # def self.mock_card_error
  #   raise CardError.new("テスト用のカードエラー", "card_number", "invalid_number")
  # end
end
