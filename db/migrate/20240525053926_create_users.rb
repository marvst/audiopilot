class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :spotify_user_id
      t.string :spotify_refresh_token

      t.timestamps
    end
  end
end
