class CreateTariffs < ActiveRecord::Migration
  def change
    create_table :tariffs do |t|
      t.text :note
      t.text :code
      t.datetime :started_at
      t.boolean :is_active

      t.timestamps
    end
  end
end
