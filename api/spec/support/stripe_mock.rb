# frozen_string_literal: true

# テスト用のStripeモック
module StripeMock
  def self.setup
    # Stripeクラスが存在しない場合は、モックで作成
    unless Object.const_defined?("Stripe")
      Object.const_set(:Stripe, Module.new)
    end

    # Stripe::Chargeクラスをモック作成
    unless Stripe.const_defined?("Charge")
      Stripe.const_set(:Charge, Class.new)
    end

    # Stripe::CardErrorクラスをモック作成
    unless Stripe.const_defined?("CardError")
      Stripe.const_set(:CardError, Class.new(StandardError))
    end

    # Stripe::Charge.createメソッドをモック
    Stripe::Charge.define_singleton_method(:create) do |params|
      if params[:source] == "tok_visa"
        # 成功した場合
        charge = Object.new
        charge.define_singleton_method(:id) { "ch_#{SecureRandom.hex(10)}" }
        charge.define_singleton_method(:status) { "succeeded" }
        charge
      else
        # 失敗した場合
        error = Object.new
        error.define_singleton_method(:message) { "カードが拒否されました" }
        # 引数シグネチャを本家Stripegemに合わせる
        raise Stripe::CardError.new("カードが拒否されました", params[:source], code: "card_declined")
      end
    end
  end

  def self.teardown
    # モックを元に戻す
    if Object.const_defined?("Stripe")
      if Stripe.const_defined?("Charge")
        Stripe.send(:remove_const, :Charge)
      end

      if Stripe.const_defined?("CardError")
        Stripe.send(:remove_const, :CardError)
      end
    end
  end
end
