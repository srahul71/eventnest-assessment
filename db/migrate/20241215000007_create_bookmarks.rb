class CreateBookmarks < ActiveRecord::Migration[7.1]
  def change
    create_table :bookmarks do |t|
      t.bigint :user_id, null: false
      t.bigint :event_id, null: false
      t.timestamps
    end

    add_index :bookmarks, [:user_id, :event_id], unique: true
    add_index :bookmarks, :event_id
  end
end
