class CreateDebuggingCases < ActiveRecord::Migration[8.1]
  def change
    create_table :debugging_cases do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.text :customer_reference
      t.string :environment
      t.datetime :archived_at

      t.timestamps
    end
  end
end
