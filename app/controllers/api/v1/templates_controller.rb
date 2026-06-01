# frozen_string_literal: true

module API
  module V1
    class TemplatesController < API::V1::APIController
      skip_before_action :authenticate_user!, only: :index
      skip_after_action :verify_authorized, only: :index
      skip_after_action :verify_policy_scoped, only: :index

      def index
        @templates = Template.ordered
      end
    end
  end
end
