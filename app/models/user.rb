class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.name = auth.info.name
      user.password = Devise.friendly_token[0, 20]
      user.confirmed_at = Time.current
    end
  end

  def password_required?
    super && provider.blank?
  end

  has_many :cart_items, dependent: :destroy
  has_many :cards, through: :cart_items
  has_many :reservations, dependent: :destroy
end
