class AddNewSetWindowDaysToSiteSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :site_settings, :new_set_window_days, :integer, default: 30, null: false
  end
end
