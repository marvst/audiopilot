class User
    include Mongoid::Document

    field :email, type: String
    field :streaming_service, type: String
    field :streaming_data, type: Hash

    has_many :playlists

    def set_access_token(access_token)
      @access_token = access_token
    end

    def playlists_from_streaming_service
      SpotifyService.playlists(@access_token)
    end

    def shows_from_streaming_service
      SpotifyService.shows(@access_token)
    end
end
