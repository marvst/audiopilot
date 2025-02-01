class HomeController < ApplicationController
  def index
    redirect_to "/setup" and return if current_user

    @spotify_auth_url = "https://accounts.spotify.com/authorize?client_id=#{ENV['SPOTIFY_CLIENT_ID']}&response_type=code&redirect_uri=#{ENV['SPOTIFY_CALLBACK_URL']}&scope=user-top-read playlist-read-private playlist-modify-private playlist-modify-public user-read-email user-library-read user-read-playback-position"
  end

  def callback
    token = Base64.strict_encode64("#{ENV['SPOTIFY_CLIENT_ID']}:#{ENV['SPOTIFY_CLIENT_SECRET']}")
  
    access_tokens = HTTParty.post(
      'https://accounts.spotify.com/api/token',
      query: {
        grant_type: "authorization_code",
        code: params['code'],
        redirect_uri: ENV['SPOTIFY_CALLBACK_URL']
      },
      headers: {
        "Authorization" => "Basic #{token}",
        "Content-Type" => "application/x-www-form-urlencoded"
      }
    ).parsed_response
  
    user_details = HTTParty.get(
      'https://api.spotify.com/v1/me',
      headers: {
        "Authorization" => "Bearer #{access_tokens['access_token']}"
      }
    ).parsed_response
  
    user = User.where(email: user_details['email'], streaming_service: 'SPOTIFY').first_or_create do |u|
      u.email = user_details['email']
      u.streaming_service = "SPOTIFY"
      u.streaming_data ||= {}
      u.streaming_data['spotify_user_id'] = user_details['id']
      u.streaming_data['spotify_refresh_token'] = access_tokens['refresh_token']
    end
  
    session['user_id'] = user.id
    session['user_email'] = user_details['email']
  
    session['streaming_service'] = "SPOTIFY"
    
    session['spotify_user_id'] = user_details['id']
    session['spotify_refresh_token'] = access_tokens['refresh_token']
    session['spotify_access_token'] = access_tokens['access_token']

    redirect_to "/setup" and return
  end

  def generate_daily_drive
    user = User.find_by(spotify_user_id: session['spotify_user_id'])

    tracks = user.settings.where(key: "PLAYLIST").map do |playlist|
      get_tracks_from_playlist(playlist.value)
    end.flatten

    episodes = user.settings.where(key: "SHOW").map do |show|
      get_latest_episode_from_show(show.value)
    end

    split_size = user.settings.where(key: "SPLIT_SIZE").first.value.to_i

    daily_drive_playlist = user.settings.where(key: "DAILY_DRIVE_PLAYLIST").first.value rescue nil

    playlist_details = follows_playlist?(daily_drive_playlist)

    if daily_drive_playlist.nil? || !playlist_details.first
      Setting.destroy_by(key: "DAILY_DRIVE_PLAYLIST")

      daily_drive_playlist = create_playlist()

      Setting.create(
        user_id: session['user_id'],
        key: "DAILY_DRIVE_PLAYLIST",
        value: daily_drive_playlist
      )
    end

    updated = update_daily_drive_playlist(daily_drive_playlist, tracks, episodes, split_size)

    if updated
      flash[:info] = "Playlist generated successfully."
    else
      flash[:error] = "Playlist not generated. Please, try again."
    end

    redirect_to "/setup"
  end

  private

  def get_user_top_tracks(access_token)
    response = HTTParty.get(
        'https://api.spotify.com/v1/me/top/tracks',
        headers: {
            "Authorization" => "Bearer #{access_token}"
        },
        query: {
            time_range: "medium_term",
            limit: 20,
            offset: rand(10)
        }
    ).parsed_response

    response['items']
  end

  def update_daily_drive_playlist(playlist, tracks, episodes, split_size)
    tracks_and_episodes = []

    if episodes.empty?
      tracks_and_episodes = tracks
    else
      sliced_tracks = tracks.each_slice(split_size).to_a
    
      counter = 0
      episodes.each do |episode|
        tracks_and_episodes.push([episode] + sliced_tracks[counter])
    
        counter += 1
      end

      tracks_and_episodes.push(sliced_tracks[counter..])
    end

    uris = tracks_and_episodes.flatten.map { |item| item['uri'] }

    # Get all tracks from the current playlist
    current_tracks = HTTParty.get(
      "https://api.spotify.com/v1/playlists/#{playlist}/tracks",
      headers: {
          "Authorization" => "Bearer #{session['spotify_access_token']}"
      }
    ).parsed_response['items'].map { |item| item["track"] }

    tracks_were_deleted = HTTParty.delete(
      "https://api.spotify.com/v1/playlists/#{playlist}/tracks",
      headers: {
        "Authorization" => "Bearer #{session['spotify_access_token']}"
      },
      body: {
        tracks: current_tracks.map { |track| { uri: track['uri'] } }
      }.to_json
    ).parsed_response

    raise StadardError unless tracks_were_deleted

    response = HTTParty.put(
      "https://api.spotify.com/v1/playlists/#{playlist}/tracks",
      headers: {
        "Authorization" => "Bearer #{session['spotify_access_token']}"
      },
      query: {
        uris: uris[0..90].join(',')
      }
    ).parsed_response

    puts response

    response
  end

  def get_tracks_from_playlist(playlist_id)
    response = HTTParty.get(
      "https://api.spotify.com/v1/playlists/#{playlist_id}/tracks",
      headers: {
          "Authorization" => "Bearer #{session['spotify_access_token']}"
      }
    ).parsed_response

    response['items'].map { |item| item["track"] }
  end

  def get_latest_episode_from_show(show_id)
    response = HTTParty.get(
      "https://api.spotify.com/v1/shows/#{show_id}/episodes",
      headers: {
          "Authorization" => "Bearer #{session['spotify_access_token']}"
      },
      query: {
          market: 'US',
          limit: 1
      }
    ).parsed_response

    response['items'][0] unless response['items'][0]["resume_point"]["fully_played"]
  end

  def generate_access_token_from_refresh_token(refresh_token)
    token = Base64.strict_encode64("#{ENV['SPOTIFY_CLIENT_ID']}:#{ENV['SPOTIFY_CLIENT_SECRET']}")

    response = HTTParty.post(
        'https://accounts.spotify.com/api/token',
        query: {
            grant_type: "refresh_token",
            refresh_token: refresh_token,
            redirect_uri: ENV['SPOTIFY_CALLBACK_URL']
        },
        headers: {
            "Authorization" => "Basic #{token}",
            "Content-Type" => "application/x-www-form-urlencoded"
        }
    ).parsed_response

    response['access_token']
  end

  def create_playlist()
    response = HTTParty.post(
      "https://api.spotify.com/v1/users/#{session['spotify_user_id']}/playlists",
      headers: {
          "Authorization" => "Bearer #{session['spotify_access_token']}"
      },
      body: JSON.generate(
        {
          name: "Audiopilot",
          public: false
        }
      )
    ).parsed_response

    response['id']
  end
end

def follows_playlist?(daily_drive_playlist)
  response = HTTParty.get(
      "https://api.spotify.com/v1/playlists/#{daily_drive_playlist}/followers/contains",
      headers: {
          "Authorization" => "Bearer #{session['spotify_access_token']}"
      }
  ).parsed_response

  response
end