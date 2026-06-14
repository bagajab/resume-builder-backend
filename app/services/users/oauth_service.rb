# frozen_string_literal: true

module Users
  class OauthService
    class Error < StandardError; end

    Profile = Data.define(:provider, :uid, :email, :first_name, :last_name)

    FACEBOOK_GRAPH_VERSION = 'v21.0'

    class << self
      def authenticate_google(id_token:)
        client_id = ENV.fetch('GOOGLE_CLIENT_ID', nil)
        raise Error, 'Google sign-in is not configured' if client_id.blank?

        payload = Google::Auth::IDTokens.verify_oidc(id_token, aud: client_id)

        raise Error, 'Google account email is not verified' unless payload['email_verified']

        Profile.new(
          provider: 'google_oauth2',
          uid: payload['sub'],
          email: payload['email'],
          first_name: payload['given_name'].to_s,
          last_name: payload['family_name'].to_s
        )
      rescue Google::Auth::IDTokens::VerificationError => error
        raise Error, error.message
      end

      def authenticate_facebook(access_token:)
        app_id = ENV.fetch('FACEBOOK_APP_ID', nil)
        app_secret = ENV.fetch('FACEBOOK_APP_SECRET', nil)
        raise Error, 'Facebook sign-in is not configured' if app_id.blank? || app_secret.blank?
        raise Error, 'Missing Facebook access token' if access_token.blank?

        debug = facebook_get(
          '/debug_token',
          input_token: access_token,
          access_token: "#{app_id}|#{app_secret}"
        )

        token_data = debug['data']
        raise Error, 'Invalid Facebook token' unless token_data&.dig('is_valid')
        raise Error, 'Invalid Facebook app' unless token_data['app_id'].to_s == app_id.to_s

        profile_data = facebook_get(
          '/me',
          fields: 'id,name,email,first_name,last_name',
          access_token: access_token
        )

        raise Error, 'Facebook account email is required' if profile_data['email'].blank?

        first_name = profile_data['first_name'].presence || profile_data['name'].to_s.split(/\s+/, 2)[0].to_s
        last_name = profile_data['last_name'].presence || profile_data['name'].to_s.split(/\s+/, 2)[1].to_s

        Profile.new(
          provider: 'facebook',
          uid: profile_data['id'].to_s,
          email: profile_data['email'],
          first_name: first_name,
          last_name: last_name
        )
      rescue Users::OauthService::Error
        raise
      rescue StandardError => error
        raise Error, error.message
      end

      def find_or_create_user!(profile)
        user = User.find_by(provider: profile.provider, uid: profile.uid)
        return user if user

        existing = User.find_by(email: profile.email)
        if existing
          if existing.provider == profile.provider && existing.uid != profile.uid
            existing.update!(uid: profile.uid)
          end

          return existing
        end

        User.create!(
          provider: profile.provider,
          uid: profile.uid,
          email: profile.email,
          first_name: profile.first_name,
          last_name: profile.last_name,
          username: generate_username(profile.email),
          password: Devise.friendly_token[0, 20]
        )
      end

      private

      def generate_username(email)
        base = email.to_s.split('@').first.to_s.parameterize(separator: '_').presence || 'user'
        candidate = base
        suffix = 1

        while User.exists?(username: candidate)
          candidate = "#{base}_#{suffix}"
          suffix += 1
        end

        candidate
      end

      def facebook_get(path, params)
        uri = URI("https://graph.facebook.com/#{FACEBOOK_GRAPH_VERSION}#{path}")
        uri.query = URI.encode_www_form(params)

        request = Net::HTTP::Get.new(uri)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        body = JSON.parse(response.body)
        raise Error, body.dig('error', 'message') || 'Facebook request failed' if body['error']

        body
      rescue JSON::ParserError
        raise Error, 'Facebook request failed'
      end
    end
  end
end
