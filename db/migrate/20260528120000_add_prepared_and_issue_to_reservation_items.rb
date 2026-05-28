class AddPreparedAndIssueToReservationItems < ActiveRecord::Migration[8.0]
  def change
    add_column :reservation_items, :prepared, :boolean, default: false, null: false
    add_column :reservation_items, :issue, :string
    add_column :reservation_items, :issue_note, :string
  end
end
