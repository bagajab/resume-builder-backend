# frozen_string_literal: true

if @connection
  json.connected @connection.linked?
  json.status @connection.status
  json.telegram_username @connection.telegram_username
  json.phone_number @connection.phone_number
  json.phone_verified @connection.phone_verified
  json.linked_at @connection.linked_at
  # Present only on `create` (issuing a fresh link); nil on `show`.
  json.deep_link @result&.deep_link
else
  json.connected false
  json.status 'unlinked'
end
