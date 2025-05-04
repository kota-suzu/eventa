FactoryBot.define do
  factory :ticket_type do
    # デフォルトでは関連するeventを実際に作成する
    association :event

    sequence(:name) { |n| "チケットタイプ#{n}" }
    description { "チケットの説明文です" }
    price_cents { 100000 } # 1000円
    currency { "JPY" }
    quantity { 100 }
    sales_start_at { 1.day.ago }
    sales_end_at { 30.days.from_now }
    status { "draft" }

    # build_stubbedで使用する場合のみ遅延評価を使用
    after(:build) do |ticket_type, evaluator|
      if ticket_type.event.nil? && FactoryBot.build_strategy.is_a?(FactoryBot::Strategy::Stub)
        ticket_type.event = build_stubbed(:event)
      end
    end

    trait :free do
      price_cents { 0 }
      name { "無料チケット" }
    end

    trait :on_sale do
      status { "on_sale" }
    end

    trait :soldout do
      status { "soldout" }
    end

    trait :closed do
      status { "closed" }
    end

    # 最小限のデータだけを持つトレイト（テストの高速化用）
    trait :minimal do
      description { nil }
      # バリデーションをスキップして高速化
      to_create do |instance|
        instance.save(validate: false)
      end
    end

    # 超高速なシードデータ用（バッチ処理向け）
    trait :fast_bulk do
      # バルクインサート用の最小データ
      to_create do |instance|
        # 既に設定されていない場合のみイベントを設定
        instance.event ||= association(:event, strategy: :create)
        # 存在しないデータをDBに直接高速挿入
        ActiveRecord::Base.connection.execute(<<~SQL)
          INSERT INTO ticket_types 
          (name, event_id, price_cents, currency, quantity, sales_start_at, sales_end_at, status, created_at, updated_at)
          VALUES
          (
            '#{instance.name}', 
            #{instance.event_id}, 
            #{instance.price_cents || 100000}, 
            '#{instance.currency || "JPY"}', 
            #{instance.quantity || 100}, 
            '#{instance.sales_start_at || Time.current - 1.day}', 
            '#{instance.sales_end_at || Time.current + 30.days}', 
            '#{instance.status || "draft"}',
            '#{Time.current.to_s(:db)}',
            '#{Time.current.to_s(:db)}'
          )
        SQL
        # IDを取得して設定
        last_id = ActiveRecord::Base.connection.execute("SELECT LAST_INSERT_ID() as id").first["id"]
        instance.id = last_id
        instance.reload
      end
    end
  end
end
