class AddAdminUserMatias < ActiveRecord::Migration[8.0]
  def up
    User.create!(
      email: "matias.laino@gmail.com",
      password: "Lalogia00",
      password_confirmation: "Lalogia00",
      admin: true
    )
  end

  def down
    User.find_by(email: "matias.laino@gmail.com")&.destroy
  end
end
