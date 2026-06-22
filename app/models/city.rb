# frozen_string_literal: true

# == Schema Information
#
# Table name: cities
#
#  id                   :bigint           not null, primary key
#  normalized_value     :string           not null
#  position             :integer          default(0), not null
#  status               :string           default("approved"), not null
#  usage_count          :integer          default(0), not null
#  value                :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  submitted_by_user_id :bigint
#
# Indexes
#
#  index_cities_on_normalized_value      (normalized_value) UNIQUE
#  index_cities_on_status                (status)
#  index_cities_on_submitted_by_user_id  (submitted_by_user_id)
#  index_cities_on_value_trgm            (value) USING gin
#
# Foreign Keys
#
#  fk_rails_...  (submitted_by_user_id => users.id)
#
class City < ApplicationRecord
  include Lookups::Optionable
end
