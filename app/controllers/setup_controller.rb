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
  rescue StandardError
    flash[:error] = "Failed to save changes. Please, try again."
  ensure
    redirect_to "/setup"
  end

  def sign_out
    reset_session
    redirect_to "/", notice: "Successfully signed out."
  end

  def generate_playlist
    if @current_user.playlist['streaming_playlist_id'].nil?
      streaming_playlist_id = SpotifyService.create_playlist("Audiopilot", session['spotify_user_id'], session["spotify_access_token"])

      @current_user.playlist.update_attribute('streaming_playlist_id', streaming_playlist_id)
    end
    
    tracks = @current_user.playlist['playlists'].map do |playlist|
      SpotifyService.tracks_from_playlist(playlist, session['spotify_access_token'])
    end.flatten

    episodes = @current_user.playlist['shows'].map do |show|
      SpotifyService.latest_not_fully_played_episode_from_show(show, session['spotify_access_token'])
    end

    tracks_and_episodes = []

    if episodes.empty?
      tracks_and_episodes = tracks
    else
      sliced_tracks = tracks.each_slice(@current_user.playlist['split_size']).to_a
    
      counter = 0
      episodes.each do |episode|
        tracks_and_episodes.push([episode] + sliced_tracks[counter])
    
        counter += 1
      end

      tracks_and_episodes.push(sliced_tracks[counter..])
    end

    content = tracks_and_episodes.flatten.map { |item| item['uri'] }

    SpotifyService.update_playlist(@current_user.playlist['streaming_playlist_id'], content, session['spotify_access_token'])

    flash[:info] = "Playlist generated successfully."

    redirect_to "/setup"
  rescue StandardError => err
    flash[:error] = "Failed to generate playlist. Please, try again."
    puts
    puts
    puts
    puts
    puts err
    puts
    puts
    puts

    redirect_to "/setup"
  end
end

