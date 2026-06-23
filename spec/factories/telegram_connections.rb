# frozen_string_literal: true

FactoryBot.define do
  factory :telegram_connection do
    user
    status { :pending }
    link_token { TelegramConnection.generate_link_token }
    link_token_expires_at { 30.minutes.from_now }

    trait :linked do
      status { :linked }
      telegram_chat_id { 123_456_789 }
      telegram_user_id { 987_654_321 }
      telegram_username { 'tguser' }
      phone_number { '+251911223344' }
      phone_verified { true }
      linked_at { Time.current }
      link_token { nil }
      link_token_expires_at { nil }
    end
  end
end
