# frozen_string_literal: true

module API
  module V1
    class SessionsController < DeviseTokenAuth::SessionsController
      include API::Concerns::ActAsAPIRequest
      include API::Concerns::FindUserByEmailForAuth
      include API::Concerns::FreshTokenOnSignIn

      protect_from_forgery with: :null_session

      private

      def create_and_assign_token
        @token, @auth_headers = create_fresh_token_for!(@resource)
      end

      def resource_params
        params.expect(user: %i[email password])
      end

      def render_create_success
        # DeviseTokenAuth's after_action can skip headers (e.g. with enable_standard_devise_support);
        # set them explicitly, matching OauthController, so clients can persist auth.
        response.headers.merge!(@auth_headers)
        render :create
      end

      def render_error(status, message, _data = nil)
        render json: { errors: Array.wrap(message:) }, status:
      end
    end
  end
end
