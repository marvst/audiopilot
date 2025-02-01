class Playlist
  include Mongoid::Document

  field :streaming_playlist_id, type: String
  field :playlists, type: Array
  field :shows, type: Array
  field :split_size, type: Integer

  belongs_to :user
end
