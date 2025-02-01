class SetupController < ApplicationController  
  before_action :authenticate_user!

  def index
    @playlists_from_streaming_service = current_user.playlists_from_streaming_service
    @shows_from_streaming_service = current_user.shows_from_streaming_service

    @playlist_config = current_user.playlist || {}
  rescue StandardError
    flash[:error] = "Something weird happened. Please, try again."
  end

  def save_setup
    playlist = @current_user.playlist || @current_user.build_playlist
  
    playlist.assign_attributes(
      playlists: params[:playlists],
      shows: params[:shows],
      split_size: params[:split_size].to_i
    )
  
    playlist.upsert(replace: true)

    flash[:info] = "Changes saved successfully."
  rescue Exception => e
    flash[:error] = "Failed to save changes. Please, try again."
    puts
    puts
    puts "ERROR: #{e}"
    puts
    puts
  ensure
    redirect_to "/setup"
  end

  def sign_out
    reset_session
    redirect_to "/", notice: "Successfully signed out."
  end
end

