class CreateReservationNotes < ActiveRecord::Migration[7.1]
  def change
    create_table :reservation_notes do |t|
      t.references :reservation, null: false, foreign_key: true
      t.text :body, null: false

      t.timestamps
    end
  end
end
