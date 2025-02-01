class Playlist
  include Mongoid::Document

  field :playlists, type: Array
  field :shows, type: Array
  field :split_size, type: Integer

  belongs_to :user
end
