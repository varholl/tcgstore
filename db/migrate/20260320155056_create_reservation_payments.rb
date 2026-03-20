class CreateReservationPayments < ActiveRecord::Migration[8.0]
  def change
    create_table :reservation_payments do |t|
      t.references :reservation, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :note

      t.timestamps
    end
  end
end
