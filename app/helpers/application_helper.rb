module ApplicationHelper    
    def authenticate_user!
        unless current_user
            flash[:info] = "Sign in to your account first."
            redirect_to "/" and return
        end

        current_user.set_access_token(session['spotify_access_token'])
    end

    def current_user
        @current_user ||= User.where(email: session['user_email'], streaming_service: 'SPOTIFY').first if session['user_email']
    end
end
