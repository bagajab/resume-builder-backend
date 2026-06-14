# frozen_string_literal: true

json.id         user.id
json.email      user.email
json.name       user.full_name
json.username   user.username
json.first_name user.first_name
json.last_name  user.last_name
json.uid        user.uid
json.provider   user.provider
json.password_set user.password_set
json.needs_password_setup user.needs_password_setup?
json.created_at user.created_at
json.updated_at user.updated_at
