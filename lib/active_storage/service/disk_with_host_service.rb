# frozen_string_literal: true

require 'active_storage/service/disk_service'

module ActiveStorage
  class Service
    class DiskWithHostService < ActiveStorage::Service::DiskService
      def url_options
        ActiveStorage::Current.url_options.presence ||
          Rails.application.config.active_storage.default_url_options
      end
    end
  end
end
