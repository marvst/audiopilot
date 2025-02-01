module ApplicationHelper    
    def authenticate_user!
        unless current_user
            flash[:info] = "Sign in to your account first."
            redirect_to "/" and return
        end

        current_user.set_access_token(session['spotify_access_token'])
    end

    def current_user
        @current_user ||= User.find_by(spotify_user_id: session['spotify_user_id']) if session['spotify_user_id']
    end
end
