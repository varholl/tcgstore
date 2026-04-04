class AddAddressFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :dni, :string
    add_column :users, :address, :string
    add_column :users, :address_number, :string
    add_column :users, :zipcode, :string
    add_column :users, :city, :string
    add_column :users, :province, :string
    add_column :users, :between_streets, :string
  end
end
