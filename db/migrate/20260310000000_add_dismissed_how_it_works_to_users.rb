class AddDismissedHowItWorksToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :dismissed_how_it_works, :boolean, default: false, null: false
  end
end
