class CreateReservations < ActiveRecord::Migration[6.1]
  def change
    create_table :reservations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, default: "pending", null: false
      t.text :message

      t.timestamps
    end

    add_index :reservations, :status
  end
end
