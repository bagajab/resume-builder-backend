# frozen_string_literal: true

module Telegram
  # Builds the URL of the "refine alert" Telegram Mini App (a route on the
  # frontend) carrying the signed, single-use refine token.
  module MiniApp
    PATH = '/telegram/job-alerts/edit'

    module_function

    def refine_url(token)
      base = ENV.fetch('FRONTEND_URL', 'http://localhost:3001').delete_suffix('/')
      "#{base}#{PATH}?t=#{token}"
    end
  end
end
