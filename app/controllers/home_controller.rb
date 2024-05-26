class HomeController < ApplicationController
  def index
    if user_logged_in?
      puts
      puts
      puts
      puts
      puts
      puts "USER IS ALREADY LOGGED IN"
      puts
      puts
      puts
      puts
      redirect_to "/setup"
    end

    @spotify_auth_url = "https://accounts.spotify.com/authorize?client_id=#{ENV['SPOTIFY_CLIENT_ID']}&response_type=code&redirect_uri=#{ENV['SPOTIFY_CALLBACK_URL']}&scope=user-top-read playlist-modify-private user-read-email"
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
    session['spotify_user_id'] = user_details['id']
    session['spotify_user_email'] = user_details['email']
    session['spotify_refresh_token'] = access_tokens['refresh_token']
    session['spotify_access_token'] = access_tokens['access_token']

    redirect_to "/setup"
  end

  def setup
    redirect_to "/" unless user_logged_in?

    @playlists = HTTParty.get(
      "https://api.spotify.com/v1/users/#{session['spotify_user_id']}/playlists",
      headers: {
        "Authorization" => "Bearer #{session['spotify_access_token']}"
      }
    ).parsed_response['items']
  end

  def save_setup
    playlist_id = params[:playlist]
    shows_ids = params[:shows].split(",")


    # TODO: Save information to the database
  end

  def log_out
    reset_session

    redirect_to "/"
  end

  private

  def user_logged_in?
    session['user_id'] &&
    session['spotify_user_id'] &&
    session['spotify_user_email'] &&
    session['spotify_refresh_token'] &&
    session['spotify_access_token']
  end
end
