class HomeController < ApplicationController
  def index
    redirect_to "/setup" if user_logged_in?

    @spotify_auth_url = "https://accounts.spotify.com/authorize?client_id=#{ENV['SPOTIFY_CLIENT_ID']}&response_type=code&redirect_uri=#{ENV['SPOTIFY_CALLBACK_URL']}&scope=user-top-read playlist-modify-private user-read-email user-library-read"
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
    Setting.destroy_by(user_id: session['user_id'])

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

      # tracks = get_user_top_tracks(access_token)

      todays_episodes = get_last_episodes_from_user_shows(access_token, user.settings.where(key: 'SHOW_ID')).select do |episode|
          release_date =  Date.parse(episode['release_date'])

          release_date == Date.today ||
          [0, 6].include?(release_date.wday) && Date.today.wday == 1
      end

      updated = update_daily_drive_playlist(access_token, config[:playlist], tracks, todays_episodes)

      if updated
          return "All good :)" 
      else
          return "No good :("
      end
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

  def update_daily_drive_playlist(access_token, playlist_id, tracks, episodes)
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
          "https://api.spotify.com/v1/playlists/#{playlist_id}/tracks",
          headers: {
              "Authorization" => "Bearer #{access_token}"
          },
          query: {
              uris: uris.join(',')
          }
      ).parsed_response

      response 
  end

  def get_last_episodes_from_user_shows(access_token, shows)
      last_episodes = []

      shows.each do |show|
          response = HTTParty.get(
              "https://api.spotify.com/v1/shows/#{show[:value]}/episodes",
              headers: {
                  "Authorization" => "Bearer #{access_token}"
              },
              query: {
                  market: 'US',
                  limit: 1
              }
          ).parsed_response

          last_episodes.push(response['items'][0])
      end

      last_episodes
  end

  def generate_access_token_from_refresh_token(refresh_token)
    token = Base64.strict_encode64("#{ENV['SPOTIFY_CLIENT_ID']}:#{ENV['SPOTIFY_CLIENT_SECRET']}")

    response = HTTParty.post(
        'https://accounts.spotify.com/api/token',
        query: {
            grant_type: "refresh_token",
            refresh_token: refresh_token,
            redirect_uri: CALLBACK_URI
        },
        headers: {
            "Authorization" => "Basic #{token}",
            "Content-Type" => "application/x-www-form-urlencoded"
        }
    ).parsed_response

    response['access_token']
  end
end
