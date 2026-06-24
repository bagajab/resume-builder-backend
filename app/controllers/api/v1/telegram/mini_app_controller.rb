# frozen_string_literal: true

module API
  module V1
    module Telegram
      # Backend for the "refine alert" Telegram Mini App. Authenticated entirely by
      # Telegram (NOT Devise): every request must carry a valid, fresh `initData`
      # (HMAC-verified with the bot token) and a signed, single-use refine token.
      # The two are cross-checked against each other and the TelegramConnection so a
      # user can only ever touch an alert they own.
      class MiniAppController < ActionController::API
        include Pundit::Authorization
        include API::Concerns::JobAlertParams

        INIT_DATA_HEADER = 'X-Telegram-Init-Data'
        TOKEN_HEADER = 'X-Telegram-Refine-Token'
        RATE_LIMIT = 60
        RATE_WINDOW = 1.minute

        before_action :throttle!
        before_action :authenticate_mini_app!

        rescue_from Pundit::NotAuthorizedError, with: :forbidden
        rescue_from ActiveRecord::RecordInvalid, with: :record_invalid

        # GET: load the alert (prefill) + why the disliked job matched.
        def show
          @job_alert = @notification.job_alert
          @job = @notification.job
          authorize @job_alert, :show?
        end

        # PATCH: refine the alert, then consume the (single-use) token.
        def update
          @job_alert = @notification.job_alert
          authorize @job_alert, :update?
          @job_alert.update!(job_alert_params)
          @notification.consume_refine_token!
          audit('refined')
          @job = @notification.job
          render :show
        end

        private

        # --- authentication ---------------------------------------------------

        def authenticate_mini_app!
          @web_app = ::Telegram::WebAppData.verify(web_app_header)
          return reject!('invalid_init_data') if @web_app.nil?

          @payload = ::Telegram::FeedbackToken.verify(token_header)
          return reject!('invalid_token') if @payload.nil?

          @notification = JobAlertNotification.find_by(id: @payload[:nid])
          reject!('context_mismatch') unless valid_context?
        end

        def web_app_header = request.headers[INIT_DATA_HEADER]
        def token_header = request.headers[TOKEN_HEADER]

        # The token's alert id must match the notification and its single-use jti
        # must still be active, AND the Telegram user must be one-and-the-same
        # across the token, the verified initData, and the alert owner's connection.
        def valid_context?
          return false if @notification.nil?
          return false unless @notification.job_alert_id == @payload[:jaid]
          return false unless @notification.refine_token_active?(@payload[:jti])

          same_telegram_user?
        end

        def same_telegram_user?
          connection = TelegramConnection.linked.find_by(user_id: @notification.user_id)
          owner_id = connection&.telegram_user_id.to_i
          return false if owner_id.zero?

          [@payload[:uid], @web_app.user_id].all? { |id| id.to_i == owner_id }
        end

        # The acting user for Pundit is resolved server-side from the token, never
        # from the client.
        def pundit_user
          @notification.job_alert.user
        end

        # --- rate limiting (store-agnostic; no-ops under a null cache) ---------

        def throttle!
          key = "telegram:mini_app:#{request.remote_ip}"
          count = (Rails.cache.read(key) || 0) + 1
          Rails.cache.write(key, count, expires_in: RATE_WINDOW)
          return if count <= RATE_LIMIT

          render json: { errors: [{ message: 'Too many requests' }] }, status: :too_many_requests
        end

        # --- responses / audit ------------------------------------------------

        def reject!(reason)
          audit("rejected:#{reason}")
          render json: { errors: [{ message: 'Unauthorized' }] }, status: :unauthorized
        end

        def forbidden
          render json: { errors: [{ message: 'Forbidden' }] }, status: :forbidden
        end

        def record_invalid(exception)
          render json: { errors: Array.wrap(exception.record.errors.as_json) }, status: :bad_request
        end

        def audit(event)
          Rails.logger.info(
            "[Telegram::MiniApp] #{event} ip=#{request.remote_ip} " \
            "tg_user=#{@web_app&.user_id} notification=#{@notification&.id}"
          )
        end
      end
    end
  end
end
