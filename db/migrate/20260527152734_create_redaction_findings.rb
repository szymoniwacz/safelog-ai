class CreateRedactionFindings < ActiveRecord::Migration[8.1]
  def change
    create_table :redaction_findings do |t|
      t.references :log_source, null: false, foreign_key: true
      t.string :finding_type, null: false
      t.integer :line_number, null: false
      t.string :placeholder, null: false
      t.string :risk_level, null: false

      t.timestamps
    end
  end
end
