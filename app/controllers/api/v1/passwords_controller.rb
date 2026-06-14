# frozen_string_literal: true

module API
  module V1
    class PasswordsController < DeviseTokenAuth::PasswordsController
      include API::Concerns::ActAsAPIRequest
      include API::Concerns::FindUserByEmailForAuth

      protect_from_forgery with: :null_session

      def update
        if require_client_password_reset_token? && resource_params[:reset_password_token]
          @resource = resource_class.with_reset_password_token(resource_params[:reset_password_token])
          return render_update_error_unauthorized unless @resource && @resource.reset_password_period_valid?

          @token = @resource.create_token
        else
          @resource = set_user_by_token
        end

        return render_update_error_unauthorized unless @resource

        unless password_update_permitted?
          return render_update_error_password_not_required
        end

        unless password_resource_params[:password] && password_resource_params[:password_confirmation]
          return render_update_error_missing_password
        end

        if @resource.send(resource_update_method, password_resource_params)
          @resource.password_set = true
          @resource.allow_password_change = false if recoverable_enabled?
          @resource.save!

          yield @resource if block_given?
          return render_update_success
        end

        render_update_error
      end

      private

      def password_update_permitted?
        @resource.provider == 'email' || @resource.allow_password_change
      end

      def redirect_options
        { allow_other_host: true }
      end

      def render_error(status, message, _data = nil)
        render json: { errors: Array.wrap(message:) }, status:
      end
    end
  end
end
