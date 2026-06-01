# frozen_string_literal: true

json.templates @templates do |template|
  json.partial! 'api/v1/templates/template', template:
end
