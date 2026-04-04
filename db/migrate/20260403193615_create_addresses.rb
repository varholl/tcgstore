class CreateAddresses < ActiveRecord::Migration[8.0]
  def change
    create_table :addresses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :address
      t.string :address_number
      t.string :zipcode
      t.string :city
      t.string :province
      t.string :between_streets

      t.timestamps
    end
  end
end
