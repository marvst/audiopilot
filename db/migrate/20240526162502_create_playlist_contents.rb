class CreatePlaylistContents < ActiveRecord::Migration[7.1]
  def change
    create_table :settings do |t|
      t.references :user, null: false, foreign_key: true
      t.string :key
      t.string :value

      t.timestamps
    end
  end
end
