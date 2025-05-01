class User < ApplicationRecord
  has_secure_password
  
  # Relations
  has_many :events, dependent: :destroy
  has_many :participants, dependent: :destroy
  has_many :participating_events, through: :participants, source: :event
  
  # Validations
  validates :email, presence: true, uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  
  # Methods to find user by credentials
  def self.authenticate(email, password)
    user = find_by(email: email)
    return nil unless user
    return user if user.authenticate(password)
    nil
  end
end