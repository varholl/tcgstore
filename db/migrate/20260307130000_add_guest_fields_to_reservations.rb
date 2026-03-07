class AddGuestFieldsToReservations < ActiveRecord::Migration[8.0]
  def change
    add_column :reservations, :guest_name, :string
    add_column :reservations, :guest_contact, :string
    change_column_null :reservations, :user_id, true
  end
end
