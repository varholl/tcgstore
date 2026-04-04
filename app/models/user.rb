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

  validates :phone_number, format: { with: /\A\d{6,13}\z/, message: :invalid_phone }, allow_blank: true
  validates :dni, format: { with: /\A\d{8,11}\z/, message: :invalid_dni }, allow_blank: true

  has_many :addresses, dependent: :destroy

  has_one :seller
  has_many :cart_items, dependent: :destroy
  has_many :cards, through: :cart_items
  has_many :reservations, dependent: :destroy
end
