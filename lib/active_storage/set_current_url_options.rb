# frozen_string_literal: true

module ActiveStorage
  class SetCurrentUrlOptions
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      url_options = {
        host: request.host,
        port: request.port,
        protocol: request.protocol.delete_suffix('://')
      }
      url_options.delete(:port) if url_options[:port] == 80

      ActiveStorage::Current.set(url_options:) { @app.call(env) }
    end
  end
end
