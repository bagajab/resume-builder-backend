# frozen_string_literal: true

module API
  module V1
    class SessionsController < DeviseTokenAuth::SessionsController
      include API::Concerns::ActAsAPIRequest
      include API::Concerns::FindUserByEmailForAuth

      protect_from_forgery with: :null_session

      private

      def resource_params
        params.expect(user: %i[email password])
      end

      def render_create_success
        # DeviseTokenAuth's after_action can skip headers (e.g. with enable_standard_devise_support);
        # set them explicitly, matching OauthController, so clients can persist auth.
        response.headers.merge!(@resource.build_auth_headers(@token.token, @token.client))
        render :create
      end

      def render_error(status, message, _data = nil)
        render json: { errors: Array.wrap(message:) }, status:
      end
    end
  end
end
