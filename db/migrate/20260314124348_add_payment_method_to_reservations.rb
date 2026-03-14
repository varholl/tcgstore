class AddPaymentMethodToReservations < ActiveRecord::Migration[8.0]
  def change
    add_column :reservations, :payment_method, :string
  end
end
