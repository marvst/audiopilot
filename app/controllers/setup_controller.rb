class SetupController < ApplicationController  
  before_action :authenticate_user!

  def index
    @playlists_from_streaming_service = current_user.playlists_from_streaming_service
    @shows_from_streaming_service = current_user.shows_from_streaming_service

    @playlist_config = current_user.playlists.first || {}
  rescue StandardError
    flash[:error] = "Something weird happened. Please, try again."
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

