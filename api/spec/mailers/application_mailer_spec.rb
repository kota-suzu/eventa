# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationMailer do
  it "デフォルトの送信元メールアドレスが設定されていること" do
    expect(ApplicationMailer.default[:from]).to eq("from@example.com")
  end

  it "メールのデフォルトレイアウトが設定されていること" do
    expect(ApplicationMailer._layout).to eq("mailer")
  end
end
