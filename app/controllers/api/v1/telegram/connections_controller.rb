# frozen_string_literal: true

module API
  module V1
    module Telegram
      # Manages the current user's Telegram link. `create` issues a fresh deep link
      # the user opens to bind their chat; the bot finishes linking out-of-band via
      # the webhook (see WebhooksController + ::Telegram::UpdateProcessor).
      class ConnectionsController < API::V1::APIController
        include API::Concerns::JobAlertsFeature

        def show
          @connection = current_user.telegram_connection
          authorize(@connection || ::TelegramConnection.new(user: current_user), :show?)
        end

        def create
          authorize(current_user.telegram_connection || ::TelegramConnection.new(user: current_user), :create?)
          @result = ::Telegram::LinkService.call(user: current_user)
          @connection = @result.connection
          render :show
        end

        def destroy
          connection = current_user.telegram_connection
          authorize(connection || ::TelegramConnection.new(user: current_user), :destroy?)
          connection&.destroy!
          head :no_content
        end
      end
    end
  end
end
