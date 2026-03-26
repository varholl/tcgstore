class CreateSellers < ActiveRecord::Migration[8.0]
  def change
    create_table :sellers do |t|
      t.string :name, null: false
      t.string :email
      t.references :user, foreign_key: true
      t.boolean :default, default: false, null: false

      t.timestamps
    end
  end
end
