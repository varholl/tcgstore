class CreateAnnouncements < ActiveRecord::Migration[8.0]
  def change
    create_table :announcements do |t|
      t.string :title
      t.text :body, null: false
      t.boolean :active, null: false, default: true
      t.string :level, null: false, default: "info"
      t.datetime :starts_at
      t.datetime :ends_at

      t.timestamps
    end
  end
end
