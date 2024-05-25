class AuthController < ApplicationController
    def index
        # config = YAML.load_file('config.yml')
        redirect "https://accounts.spotify.com/authorize?client_id=#{CLIENT_ID}&response_type=code&redirect_uri=#{CALLBACK_URI}&scope=user-top-read playlist-modify-private"

        # if config['refresh_token'].nil?
        #     redirect "https://accounts.spotify.com/authorize?client_id=#{CLIENT_ID}&response_type=code&redirect_uri=#{CALLBACK_URI}&scope=user-top-read playlist-modify-private"
        # end

        # "You already authorized us :)"
    end
end
