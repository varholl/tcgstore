class NormalizeCardConditions < ActiveRecord::Migration[7.1]
  def up
    mapping = {
      "Near Mint" => "NM",
      "Good (Lightly Played)" => "LP",
      "Played" => "MP",
      "Heavily Played" => "HP",
      "Damaged" => "DMG"
    }

    mapping.each do |old_value, new_value|
      Card.where(condition: old_value).update_all(condition: new_value)
    end
  end

  def down
    mapping = {
      "NM" => "Near Mint",
      "LP" => "Good (Lightly Played)",
      "MP" => "Played",
      "HP" => "Heavily Played",
      "DMG" => "Damaged"
    }

    mapping.each do |old_value, new_value|
      Card.where(condition: old_value).update_all(condition: new_value)
    end
  end
end
