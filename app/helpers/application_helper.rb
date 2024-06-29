module ApplicationHelper
    def user_logged_in?
        session['user_id'].present? &&
        session['spotify_user_id'].present? &&
        session['user_email'].present? &&
        session['spotify_refresh_token'].present? &&
        session['spotify_access_token'].present?
    end
end
