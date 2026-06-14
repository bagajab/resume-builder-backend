# frozen_string_literal: true

module API
  module Concerns
    module FreshTokenOnSignIn
      extend ActiveSupport::Concern

      private

      # DeviseTokenAuth can drop the new client during save-time cleanup when the
      # user already has the max number of device tokens. Issue a single fresh token.
      def create_fresh_token_for!(user)
        user.tokens = {}
        token = user.create_token
        headers = user.build_auth_headers(token.token, token.client)
        user.save!

        [token, headers]
      end
    end
  end
end
