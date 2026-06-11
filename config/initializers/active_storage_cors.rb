# frozen_string_literal: true

# Allow cross-origin <img> loads when the frontend is served from a different host/port.
Rails.application.config.to_prepare do
  %w[
    ActiveStorage::Blobs::RedirectController
    ActiveStorage::Blobs::ProxyController
    ActiveStorage::DiskController
  ].each do |controller_name|
    controller = controller_name.safe_constantize
    next unless controller

    controller.class_eval do
      after_action :allow_cross_origin_active_storage

      private

      def allow_cross_origin_active_storage
        response.headers['Access-Control-Allow-Origin'] = '*'
        response.headers['Cross-Origin-Resource-Policy'] = 'cross-origin'
      end
    end
  end
end
