class HomeController < ApplicationController
  def index
    if !user_logged_in? 
      redirect_to(
        "https://accounts.spotify.com/authorize?client_id=#{ENV['SPOTIFY_CLIENT_ID']}&response_type=code&redirect_uri=#{ENV['SPOTIFY_CALLBACK_URL']}&scope=user-top-read playlist-modify-private user-read-email", 
        allow_other_host: true
      )
    end

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

    session['user_spotify_refresh_token'] = access_tokens['refresh_token']
    session['user_spotify_access_token'] = access_tokens['access_token']

    return
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

    user = User.find_or_create_by(email: user_details['email'])

    session['user_id'] = user.id
    session['user_spotify_id'] = user_details['id']
    session['user_email'] = user_details['email']
    session['user_spotify_refresh_token'] = access_tokens['refresh_token']
    session['user_spotify_access_token'] = access_tokens['access_token']

    redirect_to(
      "/setup"
    )
  end

  def setup
    @playlists = HTTParty.get(
      "https://api.spotify.com/v1/users/#{session['user_spotify_id']}/playlists",
      headers: {
        "Authorization" => "Bearer #{session['user_spotify_access_token']}"
      }
    ).parsed_response['items']
  end

  def save_setup
    tracks_option = params[:tracks_option]
    playlist_id = params[:playlist]
    shows_list = params[:shows]
  end

  private

  def user_logged_in?
    session['user_spotify_refresh_token'] && session['user_spotify_access_token']
  end
end
