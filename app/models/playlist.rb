class Playlist
  include Mongoid::Document

  field :name, type: String
  field :playlists, type: Array
  field :shows, type: Array

  belongs_to :user
end
