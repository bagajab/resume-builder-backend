# frozen_string_literal: true

module API
  module Concerns
    module FindUserByEmailForAuth
      extend ActiveSupport::Concern

      private

      # DeviseTokenAuth scopes password login and reset lookups to provider: 'email'.
      # Find by email alone so OAuth-linked accounts can also authenticate with a password.
      def find_resource(field, value)
        return super unless email_lookup_field?(field, value)

        @resource = find_user_by_email(value)
      end

      def email_lookup_field?(field, value)
        field.to_sym == :email || (field.to_sym == :uid && value.to_s.include?('@'))
      end

      def find_user_by_email(value)
        if database_adapter&.include?('mysql')
          field_sanitized = resource_class.connection.quote_column_name('email')
          resource_class.where("BINARY #{field_sanitized} = ?", value).first
        else
          resource_class.find_by(email: value)
        end
      end
    end
  end
end
