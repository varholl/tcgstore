class AddPublicAndUserToReservationNotes < ActiveRecord::Migration[8.0]
  def change
    add_column :reservation_notes, :public, :boolean, default: false, null: false
    add_reference :reservation_notes, :user, null: true, foreign_key: true
  end
end
