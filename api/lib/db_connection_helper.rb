# frozen_string_literal: true

# テスト環境やアプリケーション実行時のデータベース接続問題を処理するヘルパークラス
# Rails 8での接続管理の変更に対応し、一時的な接続問題から回復するメカニズムを提供
unless defined?(DatabaseConnectionHelper)
  class DatabaseConnectionHelper
    # 再試行可能なデータベースエラーリスト
    RETRIABLE_ERRORS = [
      ActiveRecord::ConnectionTimeoutError,         # 接続タイムアウト
      ActiveRecord::ConnectionNotEstablished,       # 接続未確立
      ActiveRecord::StatementInvalid,               # SQL文の問題
      ActiveRecord::ConnectionFailed,               # 接続失敗
      Mysql2::Error,                                # MySQLエラー
      Mysql2::Error::ConnectionError
    ].freeze

    # PostgreSQLが利用可能な場合のみ、関連エラーを追加
    if defined?(PG)
      RETRIABLE_ERRORS.concat([
        PG::ConnectionBad,                          # PostgreSQLエラー
        PG::ServerError
      ])
    end

    # エラーメッセージのパターン
    RETRIABLE_ERROR_MESSAGES = [
      /Lost connection/i,                           # 接続喪失
      /server has gone away/i,                      # サーバー切断
      /connection timeout/i,                        # 接続タイムアウト
      /server closed the connection/i,              # サーバーによる接続終了
      /broken pipe/i,                               # パイプ破損
      /deadlock detected/i,                         # デッドロック検出
      /lock wait timeout/i,                         # ロック待ちタイムアウト
      /query execution was interrupted/i,           # クエリ実行中断
      /connection refused/i,                        # 接続拒否
      /can't connect/i,                             # 接続不可
      /Connection timed out/i,                      # 接続タイムアウト
      /Too many connections/i,                       # 接続数超過
      /connection[\s_]time[\s_]?out/i,
      /lost[\s_]connection/i,
      /terminate[\s_]connection/i,
      /not[\s_]connected/i,
      /connection[\s_]reset/i,
      /closed[\s_]connection/i
    ].freeze

    class << self
      # データベース接続を確保する
      # @param max_attempts [Integer] 最大試行回数
      # @param retry_wait [Float] 再試行間の待機時間（秒）
      # @return [Boolean] 接続成功時はtrue、それ以外はfalse
      def ensure_connection(max_attempts: 3, retry_wait: 2.0)
        attempt = 0
        success = false

        while attempt < max_attempts && !success
          attempt += 1
          begin
            # 接続プールをリセット
            ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.connection_pool.active_connection?

            # 接続を確立
            ActiveRecord::Base.connection.verify!
            ActiveRecord::Base.connection.reconnect!

            # 接続テスト
            test_connection

            # 成功
            success = true
            Rails.logger.info "データベース接続を確立しました (試行: #{attempt})" if defined?(Rails)
            puts "データベース接続を確立しました (試行: #{attempt})" unless defined?(Rails)
          rescue => e
            if retriable_error?(e) && attempt < max_attempts
              wait_time = retry_wait * attempt  # バックオフ戦略
              message = "データベース接続エラー: #{e.class} - #{e.message}、#{wait_time}秒後に再試行します (#{attempt}/#{max_attempts})"
              Rails.logger.warn message if defined?(Rails)
              puts message unless defined?(Rails)
              sleep wait_time
            else
              message = "データベース接続の確立に失敗しました: #{e.class} - #{e.message}"
              Rails.logger.error message if defined?(Rails)
              puts message unless defined?(Rails)
              return false
            end
          end
        end

        success
      end

      # 再試行可能なエラーかどうかを判定する
      # @param error [Exception] 発生したエラー
      # @return [Boolean] 再試行可能な場合はtrue
      def retriable_error?(error)
        return true if RETRIABLE_ERRORS.any? { |error_class| error.is_a?(error_class) }

        error_message = error.message.to_s
        RETRIABLE_ERROR_MESSAGES.any? { |pattern| error_message.match?(pattern) }
      end

      # データベース接続をテストする
      # @return [Boolean] 接続が有効な場合はtrue
      # @raise [StandardError] 接続が無効な場合
      def test_connection
        # 簡単なSQLクエリを実行
        result = ActiveRecord::Base.connection.execute("SELECT 1")

        # 結果を検証
        if ActiveRecord::Base.connection.adapter_name.downcase == "mysql2"
          # MySQL
          result.first[0] == 1
        elsif ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
          # PostgreSQL
          result.first["?column?"] == 1
        else
          # その他のアダプタ
          true
        end
      end

      # ブロックをデータベース接続エラーハンドリング付きで実行
      # @param max_retries [Integer] 最大再試行回数
      # @param retry_wait [Float] 再試行間の待機時間（秒）
      # @yield 実行するブロック
      # @return [Object] ブロックの戻り値
      # @raise [StandardError] 最大再試行回数を超えても失敗した場合
      def with_connection_handling(max_retries: 3, retry_wait: 1.0)
        retries = 0

        begin
          yield
        rescue => e
          if retriable_error?(e) && retries < max_retries
            retries += 1
            wait_time = retry_wait * retries  # バックオフ戦略

            message = "データベース操作中にエラーが発生しました: #{e.class} - #{e.message}、#{wait_time}秒後に再試行します (#{retries}/#{max_retries})"
            Rails.logger.warn message if defined?(Rails)
            puts message unless defined?(Rails)

            # 接続を再確立
            ensure_connection

            # 待機して再試行
            sleep wait_time
            retry
          else
            message = "データベース操作に失敗しました: #{e.class} - #{e.message}"
            Rails.logger.error message if defined?(Rails)
            puts message unless defined?(Rails)
            raise
          end
        end
      end

      # MySQLバージョン依存の問題に対応するメソッド
      def mysql_version
        @mysql_version ||= if defined?(ActiveRecord::Base) && ActiveRecord::Base.connected? &&
            ActiveRecord::Base.connection.adapter_name.downcase.include?("mysql")
          version = begin
            ActiveRecord::Base.connection.select_value("SELECT @@version")
          rescue
            nil
          end
          if version
            Rails.logger.info("MySQL Version: #{version}") if defined?(Rails.logger)
            version
          end
        end
      end

      # MySQLバージョンが8.0以上かどうかを判定
      def mysql_8_or_newer?
        version = mysql_version
        return false unless version

        major_version = version.to_s.split(".").first.to_i
        major_version >= 8
      end

      # トランザクション分離レベル変数名を返す（MySQLバージョンに応じて）
      def isolation_variable_name
        mysql_8_or_newer? ? "transaction_isolation" : "tx_isolation"
      end

      # トランザクション分離レベルを設定する
      def set_isolation_level(level = "READ-COMMITTED")
        return unless defined?(ActiveRecord::Base) && ActiveRecord::Base.connected?

        begin
          variable_name = isolation_variable_name
          ActiveRecord::Base.connection.execute("SET #{variable_name} = '#{level}'")
          current = ActiveRecord::Base.connection.select_value("SELECT @@#{variable_name}")
          Rails.logger.info("トランザクション分離レベルを '#{level}' に設定しました（現在値: #{current}）") if defined?(Rails.logger)
          true
        rescue => e
          Rails.logger.warn("トランザクション分離レベル設定エラー: #{e.message}") if defined?(Rails.logger)
          false
        end
      end

      # データベース状態を診断
      def diagnose_database_state
        connection_info = {
          adapter: ActiveRecord::Base.connection.adapter_name,
          database: ActiveRecord::Base.connection.current_database,
          connected: ActiveRecord::Base.connected?,
          pool_size: ActiveRecord::Base.connection_pool.size,
          checkout_timeout: ActiveRecord::Base.connection_pool.checkout_timeout
        }

        if mysql_version
          connection_info[:mysql_version] = mysql_version
          connection_info[:isolation_level] = begin
            ActiveRecord::Base.connection.select_value("SELECT @@#{isolation_variable_name}")
          rescue
            "unknown"
          end
        end

        # 接続状態とプール情報
        pool_stats = {
          connections: ActiveRecord::Base.connection_pool.connections.size,
          active: ActiveRecord::Base.connection_pool.active_connections?,
          checked_out: ActiveRecord::Base.connection_pool.connections.count { |c| c.in_use? }
        }

        {connection: connection_info, pool: pool_stats}
      end
    end
  end
end

# テストフレームワークでの使用
if defined?(RSpec)
  RSpec.configure do |config|
    # 一時的なデータベース接続エラーを処理する
    config.around(:each) do |example|
      retries = 0
      begin
        example.run
      rescue => e
        if DatabaseConnectionHelper.retriable_error?(e) && retries < 2
          retries += 1
          puts "テスト中に一時的なデータベースエラーが発生しました: #{e.message}. 再試行 #{retries}/2..."
          DatabaseConnectionHelper.ensure_connection(max_attempts: 2)
          retry
        else
          raise
        end
      end
    end
  end
end
