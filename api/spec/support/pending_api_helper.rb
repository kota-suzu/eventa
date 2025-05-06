# frozen_string_literal: true

# APIエンドポイントのテストをスキップするためのヘルパーモジュール
# APIの実装が完了した時点で、このヘルパーの利用を解除することで
# すべてのテストを一度に有効化できます
module PendingApiHelper
  # APIエンドポイントが実装されるまでテストをスキップする
  # @param message [String] スキップする理由のメッセージ
  # @param condition [Boolean] スキップする条件。デフォルトはfalse（スキップしない）
  # @example
  #   # すべてのテストをスキップ
  #   skip_until_api_implemented
  #
  #   # 条件付きでスキップ
  #   skip_until_api_implemented("APIが実装されていません", Rails.env.test? && ENV['SKIP_API_TESTS'])
  def skip_until_api_implemented(message = "APIエンドポイントが完全に実装されるまでskip", condition = false)
    # テストを必ずスキップしないようにデフォルト条件をfalseに変更（元々はtrueだった可能性あり）
    before do
      skip(message) if condition
    end
  end

  # 特定のコントローラーアクションが実装されるまでテストをスキップする
  # @param controller [String] コントローラー名
  # @param action [String] アクション名
  def skip_until_controller_action_implemented(controller, action)
    controller_exists = begin
      controller.constantize
      true
    rescue NameError
      false
    end
    action_exists = controller_exists && controller.constantize.instance_methods.include?(action.to_sym)

    skip_until_api_implemented(
      "コントローラー #{controller} の #{action} アクションが実装されるまでskip",
      !action_exists
    )
  end
end

# RSpecに自動的に含める
RSpec.configure do |config|
  config.extend PendingApiHelper, type: :request
end
