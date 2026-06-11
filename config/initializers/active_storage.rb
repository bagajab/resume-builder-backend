# frozen_string_literal: true

require Rails.root.join('lib/active_storage/set_current_url_options')

host = ENV.fetch('SERVER_HOST', 'localhost')
port = ENV.fetch('PORT', 3000).to_i
protocol = Rails.env.production? ? 'https' : 'http'

default_url_options = { host:, protocol: }
default_url_options[:port] = port unless port == 80

Rails.application.config.active_storage.default_url_options = default_url_options
Rails.application.routes.default_url_options = default_url_options

# Serve blobs in one request (no redirect to /disk/ URLs that need extra url_options).
Rails.application.config.active_storage.resolve_model_to_route = :rails_storage_proxy

Rails.application.config.middleware.use ActiveStorage::SetCurrentUrlOptions
