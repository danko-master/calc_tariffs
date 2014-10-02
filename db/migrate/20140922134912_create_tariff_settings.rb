class CreateTariffSettings < ActiveRecord::Migration
  def change
    create_table :tariff_settings do |t|
      t.text :code
      
      t.timestamps
    end
  end
end
