class Tariff < ActiveRecord::Base
  before_create :set_started_at

  def set_started_at
    self.started_at = Time.now if self.started_at.blank?
  end
end
