# frozen_string_literal: true

# == Schema Information
#
# Table name: telegram_connections
#
#  id                    :bigint           not null, primary key
#  link_token            :string
#  link_token_expires_at :datetime
#  linked_at             :datetime
#  phone_number          :string
#  phone_verified        :boolean          default(FALSE), not null
#  status                :integer          default("pending"), not null
#  telegram_username     :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  telegram_chat_id      :bigint
#  telegram_user_id      :bigint
#  user_id               :bigint           not null
#
# Indexes
#
#  index_telegram_connections_on_link_token        (link_token) UNIQUE
#  index_telegram_connections_on_telegram_chat_id  (telegram_chat_id)
#  index_telegram_connections_on_user_id           (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
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
