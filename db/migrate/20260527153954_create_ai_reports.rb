class CreateAiReports < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_reports do |t|
      t.references :debugging_case, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.text :structured_json
      t.text :markdown_body

      t.timestamps
    end
  end
end
