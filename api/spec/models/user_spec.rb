require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      user = build(:user)
      expect(user).to be_valid
    end

    it "is not valid without an email" do
      user = build(:user, email: nil)
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("を入力してください")
    end

    it "is not valid with an invalid email format" do
      user = build(:user, email: "invalid-email")
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("は不正な値です")
    end

    it "is not valid with a duplicate email" do
      create(:user, email: "test@example.com")
      user = build(:user, email: "test@example.com")
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("はすでに存在します")
    end

    it "is not valid without a name" do
      user = build(:user, name: nil)
      expect(user).not_to be_valid
      expect(user.errors[:name]).to include("を入力してください")
    end

    it "is not valid with a password less than 8 characters" do
      user = build(:user, password: "short", password_confirmation: "short")
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("は8文字以上で入力してください")
    end
  end

  describe ".authenticate" do
    let(:user) { create(:user, email: "auth@example.com", password: "password123") }

    it "returns user when credentials are valid" do
      result = User.authenticate("auth@example.com", "password123")
      expect(result).to eq(user)
    end

    it "returns nil when email is invalid" do
      result = User.authenticate("wrong@example.com", "password123")
      expect(result).to be_nil
    end

    it "returns nil when password is invalid" do
      result = User.authenticate("auth@example.com", "wrongpassword")
      expect(result).to be_nil
    end
  end

  describe "associations" do
    it "has many events" do
      association = described_class.reflect_on_association(:events)
      expect(association.macro).to eq(:has_many)
    end

    it "has many participants" do
      association = described_class.reflect_on_association(:participants)
      expect(association.macro).to eq(:has_many)
    end

    it "has many participating events" do
      association = described_class.reflect_on_association(:participating_events)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:through]).to eq(:participants)
      expect(association.options[:source]).to eq(:event)
    end
  end
end
