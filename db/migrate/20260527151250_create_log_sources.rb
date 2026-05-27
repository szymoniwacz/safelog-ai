class CreateLogSources < ActiveRecord::Migration[8.1]
  def change
    create_table :log_sources do |t|
      t.references :debugging_case, null: false, foreign_key: true
      t.string :source_type, null: false
      t.string :name
      t.text :sanitized_content
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
