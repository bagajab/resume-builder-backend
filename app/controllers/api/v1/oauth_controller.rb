# frozen_string_literal: true

module API
  module V1
    class OauthController < API::V1::APIController
      skip_before_action :authenticate_user!
      skip_after_action :verify_authorized

      def google
        id_token = params[:id_token].to_s
        raise Users::OauthService::Error, 'Missing Google ID token' if id_token.blank?

        profile = Users::OauthService.authenticate_google(id_token:)
        sign_in_oauth_user(Users::OauthService.find_or_create_user!(profile))
      rescue Users::OauthService::Error => error
        render_oauth_error(error.message)
      end

      def facebook
        access_token = params[:access_token].to_s
        raise Users::OauthService::Error, 'Missing Facebook access token' if access_token.blank?

        profile = Users::OauthService.authenticate_facebook(access_token:)
        sign_in_oauth_user(Users::OauthService.find_or_create_user!(profile))
      rescue Users::OauthService::Error => error
        render_oauth_error(error.message)
      end

      private

      def sign_in_oauth_user(user)
        token = user.create_token
        user.save!

        response.headers.merge!(user.build_auth_headers(token.token, token.client))
        @resource = user
        render 'api/v1/sessions/create', status: :ok
      end

      def render_oauth_error(message)
        render json: { errors: [{ message: }] }, status: :unauthorized
      end
    end
  end
end
