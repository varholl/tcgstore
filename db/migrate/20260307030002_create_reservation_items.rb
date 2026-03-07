class CreateReservationItems < ActiveRecord::Migration[6.1]
  def change
    create_table :reservation_items do |t|
      t.references :reservation, null: false, foreign_key: true
      t.references :card, null: false, foreign_key: true
      t.integer :quantity, default: 1, null: false

      t.timestamps
    end
  end
end
