class SpotifyService
  def self.playlists(access_token)
    HTTParty.get(
      "https://api.spotify.com/v1/me/playlists",
      headers: {
        "Authorization" => "Bearer #{access_token}"
      },
      query: {
        "limit": "50"
      }
    ).parsed_response['items']
  end

  def self.shows(access_token)
    HTTParty.get(
      "https://api.spotify.com/v1/me/shows",
      headers: {
        "Authorization" => "Bearer #{access_token}"
      },
      query: {
        "limit": "50"
      }
    ).parsed_response['items']
  end
end