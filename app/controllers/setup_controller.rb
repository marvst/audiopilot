class SetupController < ApplicationController  
  before_action :authenticate_user!

  def index
    @playlists = current_user.playlists
    @shows = current_user.shows

    @config = current_user.config


    # user = User.find_by(spotify_user_id: session['spotify_user_id'])
    
    # unless user_logged_in?
    #   flash[:info] = "Sign in to your account first."
    #   redirect_to "/"
      
    #   return
    # end
    # # debugger
    # @playlists = @spotify_service.playlists
    
    # @shows = HTTParty.get(
    #   "https://api.spotify.com/v1/me/shows",
    #   headers: {
    #     "Authorization" => "Bearer #{session['spotify_access_token']}"
    #   },
    #   query: {
    #     "limit": "50"
    #   }
    # ).parsed_response['items']
    
    # @selected_playlists = user.settings.where(key: "PLAYLIST").map { |playlist| playlist.value }
    # @selected_shows = user.settings.where(key: "SHOW").map { |show| show.value }
    # @split = user.settings.where(key: "SPLIT_SIZE").first.value rescue 5
    # @time_to_generate = user.settings.where(key: "TIME_TO_GENERATE").first.value rescue 60
  rescue StandardError => err
    puts "HEREEEEEEEEE #{err}"
    flash[:error] = "Something weird happened. Please, sign in again."

    # redirect_to signout_path and return
  end

  def save_setup
    Setting.destroy_by(key: "SHOW")
    Setting.destroy_by(key: "PLAYLIST")
    Setting.destroy_by(key: "SPLIT_SIZE")
    Setting.destroy_by(key: "TIME_TO_GENERATE")

    Setting.create(
      user_id: session['user_id'],
      key: "SPLIT_SIZE",
      value: params[:split].to_i
    )

    Setting.create(
      user_id: session['user_id'],
      key: "TIME_TO_GENERATE",
      value: params[:time]
    )

    params[:playlists].each do |playlist|
      Setting.create(
        user_id: session['user_id'],
        key: "PLAYLIST",
        value: playlist
      ) 
    end

    params[:shows].each do |show|
      Setting.create(
        user_id: session['user_id'],
        key: "SHOW",
        value: show
      ) 
    end

    flash[:info] = "Changes saved successfully."
  rescue Exception => e
    flash[:error] = "Failed to save changes. Please, try again."
    puts "ERROR: #{e}"
  ensure
    redirect_to "/setup"
  end

  def sign_out
    reset_session
    redirect_to "/", notice: "Successfully signed out."
  end
end

