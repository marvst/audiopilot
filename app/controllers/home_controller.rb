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
end