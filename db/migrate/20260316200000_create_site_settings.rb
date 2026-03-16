class CreateSiteSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :site_settings do |t|
      t.boolean :maintenance_mode, default: false, null: false
      t.text :maintenance_message

      t.timestamps
    end
  end
end
