# frozen_string_literal: true

json.id option.id
json.value option.value
json.status option.status
json.usage_count option.usage_count
json.category option.category if option.has_attribute?(:category)
