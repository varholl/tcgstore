class AddAttributionToUsersAndReservations < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :acquisition_source, :string
    add_column :users, :acquisition_campaign, :string
    add_column :users, :acquisition_referrer, :string
    add_column :users, :acquired_at, :datetime

    add_column :reservations, :source, :string
    add_column :reservations, :campaign, :string
    add_column :reservations, :referrer, :string
  end
end
