class SiteSetting < ApplicationRecord
  def self.instance
    first_or_create!
  end

  def self.maintenance_mode?
    instance.maintenance_mode
  end

  def self.maintenance_message
    instance.maintenance_message
  end
end
