Rails.application.config.session_store :cookie_store,
                                       key: '_spotify_custom_daily_drive_session',
                                       expire_after: 60.minutes