# frozen_string_literal: true

json.options @options do |option|
  json.partial! 'api/v1/lookups/option', option:
end
