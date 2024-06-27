class HomeController < ApplicationController
  def index
    redirect_to "/setup" if user_logged_in?

    @spotify_auth_url = "https://accounts.spotify.com/authorize?client_id=#{ENV['SPOTIFY_CLIENT_ID']}&response_type=code&redirect_uri=#{ENV['SPOTIFY_CALLBACK_URL']}&scope=user-top-read playlist-modify-private playlist-modify-public user-read-email user-library-read user-read-playback-position"
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
    
    user = User.find_by(spotify_user_id: user_details['id'])
    user = User.create(
      email: user_details['email'],
      spotify_user_id: user_details['id'],
      spotify_refresh_token: access_tokens['refresh_token']
    ) unless user

    session['user_id'] = user.id
    session['spotify_user_id'] = user_details['id']
    session['user_email'] = user_details['email']
    session['spotify_refresh_token'] = access_tokens['refresh_token']
    session['spotify_access_token'] = access_tokens['access_token']

    redirect_to "/setup"
  end

  def setup
    redirect_to "/" unless user_logged_in?

    @playlists = HTTParty.get(
      "https://api.spotify.com/v1/me/playlists",
      headers: {
        "Authorization" => "Bearer #{session['spotify_access_token']}"
      }
    ).parsed_response['items']
    @shows = HTTParty.get(
      "https://api.spotify.com/v1/me/shows",
      headers: {
        "Authorization" => "Bearer #{session['spotify_access_token']}"
      }
    ).parsed_response['items']
  end

  def save_setup
    Setting.destroy_by(key: "SHOW")
    Setting.destroy_by(key: "PLAYLIST")
    Setting.destroy_by(key: "SPLIT_SIZE")

    Setting.create(
      user_id: session['user_id'],
      key: "PLAYLIST",
      value: params[:playlist]
    )

    Setting.create(
      user_id: session['user_id'],
      key: "SPLIT_SIZE",
      value: params[:split].to_i
    )

    params[:shows].each do |show|
      Setting.create(
        user_id: session['user_id'],
        key: "SHOW",
        value: show
      ) 
    end

    flash[:info] = "Changes saved successfully."
  rescue Exception => e
    flash[:error] = "Failed to save the changes. Try again."
    puts "ERROR: #{e}"
  ensure
    redirect_to "/setup"
  end

  def log_out
    reset_session

    redirect_to "/"
  end

  def generate_daily_drive
    User.all.each do |user|
      access_token = generate_access_token_from_refresh_token(user[:spotify_refresh_token])

      tracks = user.settings.where(key: "PLAYLIST").map do |playlist|
        get_tracks_from_playlist(
          playlist.value, 
          access_token
        )
      end.first

      episodes = user.settings.where(key: "SHOW").map do |show|
        get_latest_episode_from_show(
          show.value, 
          access_token
        )
      end

      daily_drive_playlist = user.settings.where(key: "DAILY_DRIVE_PLAYLIST").first.value

      # TODO: Check if the playlist is deleted on Spotify
      playlist_details = follows_playlist?(daily_drive_playlist, access_token)

      if daily_drive_playlist.nil? || !playlist_details.first
        Setting.destroy_by(key: "DAILY_DRIVE_PLAYLIST")

        daily_drive_playlist = create_playlist(access_token)

        Setting.create(
          user_id: session['user_id'],
          key: "DAILY_DRIVE_PLAYLIST",
          value: daily_drive_playlist
        )
      end

      updated = update_daily_drive_playlist(daily_drive_playlist, tracks, episodes, access_token)

      if updated
        flash[:info] = "Playlist generated successfully."
      else
        flash[:error] = "Playlist not generated."
      end

      redirect_to "/setup"
    end
  end

  private

  def user_logged_in?
    session['user_id'] &&
    session['spotify_user_id'] &&
    session['user_email'] &&
    session['spotify_refresh_token'] &&
    session['spotify_access_token']
  end

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

  def update_daily_drive_playlist(playlist, tracks, episodes, access_token)
    tracks_and_episodes = []

    if episodes.empty?
      tracks_and_episodes = tracks
    else
      sliced_tracks = tracks.each_slice(tracks.length / episodes.length).to_a
    
      counter = 0
      episodes.each do |episode|
        tracks_and_episodes.push([episode] + sliced_tracks[counter])
    
        counter += 1
      end
    end

    uris = tracks_and_episodes.flatten.map { |item| item['uri'] }

    response = HTTParty.put(
      "https://api.spotify.com/v1/playlists/#{playlist}/tracks",
      headers: {
        "Authorization" => "Bearer #{access_token}"
      },
      query: {
        uris: uris.join(',')
      }
    ).parsed_response

    response 
  end

  def get_tracks_from_playlist(playlist_id, access_token)
    response = HTTParty.get(
      "https://api.spotify.com/v1/playlists/#{playlist_id}/tracks",
      headers: {
          "Authorization" => "Bearer #{access_token}"
      }
    ).parsed_response

    response['items'].map { |item| item["track"] }
  end

  def get_latest_episode_from_show(show_id, access_token)
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

  def create_playlist(access_token)
    response = HTTParty.post(
      "https://api.spotify.com/v1/users/#{session['spotify_user_id']}/playlists",
      headers: {
          "Authorization" => "Bearer #{access_token}"
      },
      body: JSON.generate(
        {
          name: "Custom Daily Drive",
          public: false
        }
      )
    ).parsed_response

    response['id']
  end
end

def follows_playlist?(daily_drive_playlist, access_token)
  response = HTTParty.get(
      "https://api.spotify.com/v1/playlists/#{daily_drive_playlist}/followers/contains",
      headers: {
          "Authorization" => "Bearer #{access_token}"
      }
  ).parsed_response

  response
end