class AddOwnerNotesReadAtToReservations < ActiveRecord::Migration[8.0]
  def change
    add_column :reservations, :owner_notes_read_at, :datetime
  end
end
