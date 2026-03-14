class AddReceiptSentAtToReservations < ActiveRecord::Migration[8.0]
  def change
    add_column :reservations, :receipt_sent_at, :datetime
  end
end
