class CreateCorrelationSignals < ActiveRecord::Migration[8.1]
  def change
    create_table :correlation_signals do |t|
      t.references :debugging_case, null: false, foreign_key: true
      t.text :payload

      t.timestamps
    end
  end
end
