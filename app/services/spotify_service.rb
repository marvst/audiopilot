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

  def self.tracks_from_playlist(playlist_id, access_token)
    response = HTTParty.get(
      "https://api.spotify.com/v1/playlists/#{playlist_id}/tracks",
      headers: {
          "Authorization" => "Bearer #{access_token}"
      }
    ).parsed_response

    response['items'].map { |item| item["track"] }
  end

  def self.latest_not_fully_played_episode_from_show(show_id, access_token)
    response = HTTParty.get(
      "https://api.spotify.com/v1/shows/#{show_id}/episodes",
      headers: {
          "Authorization" => "Bearer #{access_token}"
      },
      query: {
          market: 'US',
          limit: 1
      }
    ).parsed_response

    response['items'][0] unless response['items'][0]["resume_point"]["fully_played"]
  end

  def self.create_playlist(name, user_id, access_token)
    response = HTTParty.post(
      "https://api.spotify.com/v1/users/#{user_id}/playlists",
      headers: {
          "Authorization" => "Bearer #{access_token}"
      },
      body: JSON.generate(
        {
          name: name,
          public: false
        }
      )
    ).parsed_response

    response['id']
  end

  def self.update_playlist(playlist_id, content, access_token)
    current_tracks = HTTParty.get(
      "https://api.spotify.com/v1/playlists/#{playlist_id}/tracks",
      headers: {
          "Authorization" => "Bearer #{access_token}"
      }
    ).parsed_response['items']

      unless current_tracks.nil? || current_tracks.empty?
        tracks_were_deleted = HTTParty.delete(
          "https://api.spotify.com/v1/playlists/#{playlist_id}/tracks",
          headers: {
            "Authorization" => "Bearer #{access_token}"
          },
          body: {
            tracks: current_tracks.map { |item| item["track"] }.map { |track| { uri: track['uri'] } }
          }.to_json
        ).parsed_response
        
        raise StadardError unless tracks_were_deleted
      end

    response = HTTParty.put(
      "https://api.spotify.com/v1/playlists/#{playlist_id}/tracks",
      headers: {
        "Authorization" => "Bearer #{access_token}"
      },
      query: {
        uris: content[0..90].join(',')
      }
    ).parsed_response

    response
  end
end