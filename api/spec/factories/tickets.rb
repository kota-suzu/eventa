FactoryBot.define do
  factory :ticket do
    sequence(:title) { |n| "チケット#{n}" }
    description { "チケットの説明文です" }
    price { 1000 }
    quantity { 1 }
    available_quantity { 1 }

    # 関連
    association :event
    association :ticket_type

    # 必要に応じてticket_typeから情報を設定
    before(:create) do |ticket|
      if ticket.ticket_type.present?
        ticket.title ||= ticket.ticket_type.name
        ticket.price ||= ticket.ticket_type.price_cents / 100
      end
    end

    # トランザクションのオーバーヘッドを減らすための最小設定
    trait :minimal do
      description { nil }
      to_create { |instance| instance.save(validate: false) }
    end

    # バッチ処理用の超高速バルク挿入
    trait :fast_bulk do
      to_create do |instance|
        # 関連付けの設定
        instance.event ||= association(:event, strategy: :create)

        # 直接SQLでバルクインサート
        ActiveRecord::Base.connection.execute(<<~SQL)
          INSERT INTO tickets 
          (title, event_id, ticket_type_id, price, quantity, available_quantity, created_at, updated_at)
          VALUES (
            '#{instance.title}', 
            #{instance.event_id}, 
            #{instance.ticket_type_id || "NULL"}, 
            #{instance.price || 1000}, 
            #{instance.quantity || 1},
            #{instance.available_quantity || instance.quantity || 1},
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

    # トランザクション内でのテスト用に最適化したトレイト
    trait :fast_transactional do
      # テスト中のトランザクション内での高速な作成
      to_create do |instance|
        # 最小限のチェックだけ実行
        instance.available_quantity ||= instance.quantity
        instance.save(validate: false)
      end
    end
  end
end
